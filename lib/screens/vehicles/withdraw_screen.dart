import 'package:ac_app/services/bank_details_service.dart';
import 'package:ac_app/services/transaction_service.dart';
import 'package:ac_app/services/user_profile_service.dart';
import 'package:ac_app/constants/transaction_constants.dart';
import 'package:ac_app/utils/redemption_dates.dart';
import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/styled_card.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/shared/styled_textfield.dart';
import 'package:ac_app/shared/success_dialog.dart';
import 'package:ac_app/theme.dart';
import 'package:ac_app/widgets/bank_details_modal.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WithdrawFunds extends StatefulWidget {
  static const routeName = '/withdraw';
  const WithdrawFunds({super.key});

  @override
  State<WithdrawFunds> createState() => _WithdrawFundsState();
}

class _WithdrawFundsState extends State<WithdrawFunds> {
  final TextEditingController _amountController = TextEditingController();
  int? _vehicleId;
  bool _submitting = false;
  bool _loading = true;
  BankDetails? _bankDetails;
  double? _currentBalance;
  double _feeAmount = 0.0;
  double _totalAmount = 0.0; // Total deduction from balance (withdrawal + fees)
  double _totalWithdraw = 0.0; // What user actually receives (withdrawal - fees)
  double _redemptionPenalty = 0.0;
  double _gatePenalty = 0.0;

  @override
  void initState() {
    super.initState();
    _amountController.text = '0.00';
    _amountController.addListener(_calculateFee);
    _loadBankDetails();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get vehicle ID from navigation arguments
    final vehicleId = ModalRoute.of(context)?.settings.arguments as int?;
    if (_vehicleId != vehicleId) {
      _vehicleId = vehicleId;
      _loadCurrentBalance();
    }
  }

  Future<void> _loadBankDetails() async {
    try {
      final details = await BankDetailsService.getBankDetails();
      if (mounted) {
        setState(() {
          _bankDetails = details;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadCurrentBalance() async {
    if (_vehicleId == null) return;

    try {
      final uid = UserProfileService().profile?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('userinvestmentvehicle')
          .select('current_balance')
          .eq('user_uid', uid)
          .eq('vehicle_id', _vehicleId!)
          .maybeSingle();

      if (mounted && response != null) {
        setState(() {
          _currentBalance = (response['current_balance'] as num?)?.toDouble() ?? 0.0;
        });
      }
    } catch (e) {
      print('[WithdrawScreen] Error loading current balance: $e');
    }
  }

  void _calculateFee() {
    final amountText = _amountController.text.replaceAll(',', '');
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0 || _currentBalance == null) {
      setState(() {
        _feeAmount = 0.0;
        _totalAmount = 0.0;
        _totalWithdraw = 0.0;
        _redemptionPenalty = 0.0;
        _gatePenalty = 0.0;
      });
      return;
    }

    // Calculate penalties sequentially (same logic as TransactionService)
    final isRedemptionDate = RedemptionDates.isRedemptionDate(DateTime.now());
    final threshold = _currentBalance! / 3.0;
    
    double withdrawalAfterPenalties = amount;
    double redemptionPenalty = 0.0;
    double gatePenalty = 0.0;
    
    // STEP 1: Apply redemption penalty (5% on NON-redemption dates)
    // This reduces the withdrawal amount by 5%
    if (!isRedemptionDate) {
      redemptionPenalty = amount * 0.05;
      withdrawalAfterPenalties = amount - redemptionPenalty;
    }
    
    // STEP 2: Check if original withdrawal amount >= 33.33% of balance
    // If yes, apply gate penalty (5%) to the NEW withdrawal amount (after redemption penalty)
    if (amount >= threshold) {
      gatePenalty = withdrawalAfterPenalties * 0.05;
      withdrawalAfterPenalties = withdrawalAfterPenalties - gatePenalty;
    }
    
    final totalFee = redemptionPenalty + gatePenalty;
    // Total deduction from balance = original withdrawal amount
    // Final withdraw (what user receives) = withdrawal amount after all penalties
    final totalDeduction = amount; // Original withdrawal amount (what gets deducted from balance)
    final totalWithdraw = withdrawalAfterPenalties; // What user actually receives

    setState(() {
      _feeAmount = totalFee;
      _totalAmount = totalDeduction; // Original withdrawal amount (what gets deducted from balance)
      _totalWithdraw = totalWithdraw; // This is what user actually receives
      _redemptionPenalty = redemptionPenalty;
      _gatePenalty = gatePenalty;
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_calculateFee);
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleWithdrawal() async {

    // Check if bank details are complete
    if (_bankDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add your bank details first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_vehicleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle information missing')),
      );
      return;
    }

    if (_currentBalance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load current balance')),
      );
      return;
    }

    // Parse amount from controller
    final amountText = _amountController.text.replaceAll(',', '');
    final amount = double.tryParse(amountText);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Check if user has sufficient balance (including fee)
    if (_totalAmount > _currentBalance!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Insufficient balance. Available: ₱${_currentBalance!.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // Create transaction record with PENDING status
      // IMPORTANT: For withdrawals, the 'amount' field stores the TOTAL DEDUCTION (withdrawal + fee)
      // This is what the admin should deduct from current_balance when approving
      // To get the withdrawal amount (what user receives), calculate: amount - fee
      // Fee can be recalculated using TransactionService.calculateWithdrawalFee()
      await TransactionService.createTransaction(
        transactionTypeId: TransactionType.withdrawal,
        amount: _totalAmount, // Total deduction from balance (withdrawal + fee)
        bankDetailId: _bankDetails!.id,
        status: TransactionStatus.pending,
        vehicleId: _vehicleId, // Store vehicle_id for later processing
      );

      if (!mounted) return;

      // Build success message
      String message = 'Withdrawal submitted!';
      if (_feeAmount > 0) {
        message += '\n\nWithdrawal: ₱${amount.toStringAsFixed(2)}';
        message += '\nFee (5%): ₱${_feeAmount.toStringAsFixed(2)}';
        message += '\nTotal deduction: ₱${_totalAmount.toStringAsFixed(2)}';
      } else {
        message += '\n\nAmount: ₱${amount.toStringAsFixed(2)}';
      }
      message += '\n\nWaiting for admin verification.';

      // Show success dialog
      await showSuccessDialog(context, message);

      // Return true to signal successful Withdrawal submission
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Withdrawal failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        // title: const Text('Withdrawal Funds'),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          BankDetailsCard(
                            bankName: _bankDetails?.bankName ?? 'N/A',
                            accountNumber: _bankDetails?.accountNumber ?? 'N/A',
                            locationName: _bankDetails?.location ?? 'N/A',
                            accountName: _bankDetails?.accountName ?? 'N/A',
                            onTap: () {
                              try {
                                showBankDetailsModal(
                                  context,
                                  existingDetails: _bankDetails,
                                  onSaved: () {
                                    _loadBankDetails();
                                  },
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error opening bank details: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 50.0),
                          TitleText('Withdrawal Funds', fontSize: 24),
                          const SizedBox(height: 8.0),
                          if (_currentBalance != null) ...[
                            SecondaryText(
                              'Available Balance: ₱${_currentBalance!.toStringAsFixed(2)}',
                              fontSize: 16,
                              color: AppColors.primaryColor,
                            ),
                            const SizedBox(height: 4.0),
                          ],
                          Builder(
                            builder: (context) {
                              final nextRedemption = RedemptionDates.getNextRedemptionDate();
                              final redemptionText = nextRedemption != null
                                  ? RedemptionDates.formatRedemptionDate(nextRedemption)
                                  : 'TBD';
                              
                              return SecondaryText(
                                'Next redemption period is on $redemptionText. Request withdrawals on redemption dates to avoid redemption fees. Gate fees are still applicable.',
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              );
                            },
                          ),
                          const SizedBox(height: 24.0),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: DigitField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              label: 'Amount',
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          // Fee and total information
                          if (_currentBalance != null && _totalAmount > 0) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24.0),
                              child: Container(
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: _feeAmount > 0 ? Colors.orange.shade50 : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(
                                    color: _feeAmount > 0 ? Colors.orange.shade200 : Colors.green.shade200,
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Penalties breakdown
                                    if (_feeAmount > 0) ...[
                                      if (_redemptionPenalty > 0) ...[
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            SecondaryText(
                                              'Redemption Penalty (5%):',
                                              fontSize: 14,
                                              color: Colors.orange.shade700,
                                            ),
                                            SecondaryText(
                                              '₱${_redemptionPenalty.toStringAsFixed(2)}',
                                              fontSize: 14,
                                              color: Colors.orange.shade700,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6.0),
                                      ],
                                      if (_gatePenalty > 0) ...[
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            TitleText(
                                              'Gate Penalty (5%):',
                                              fontSize: 14,
                                              color: Colors.red.shade700,
                                            ),
                                            TitleText(
                                              '₱${_gatePenalty.toStringAsFixed(2)}',
                                              fontSize: 14,
                                              color: Colors.red.shade700,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6.0),
                                      ],
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          TitleText(
                                            'Total Penalties:',
                                            fontSize: 14,
                                            color: Colors.orange.shade700,
                                          ),
                                          TitleText(
                                            '₱${_feeAmount.toStringAsFixed(2)}',
                                            fontSize: 14,
                                            color: Colors.orange.shade700,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12.0),
                                      const Divider(height: 1.0),
                                      const SizedBox(height: 12.0),
                                    ],
                                    // Total Withdraw (withdrawal amount - penalties = what you actually receive)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        TitleText(
                                          'Total Withdraw:',
                                          fontSize: 18,
                                          color: AppColors.primaryColor,
                                        ),
                                        TitleText(
                                          '₱${_totalWithdraw.toStringAsFixed(2)}',
                                          fontSize: 18,
                                          color: AppColors.primaryColor,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12.0),
                                    const Divider(height: 1.0),
                                    const SizedBox(height: 12.0),
                                    // Balance After
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        SecondaryText(
                                          'Balance After:',
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                        TitleText(
                                          '₱${(_currentBalance! - _totalAmount).toStringAsFixed(2)}',
                                          fontSize: 16,
                                          color: AppColors.primaryColor,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8.0),
                          ],
                          const SizedBox(height: 8.0),
                        ],
                      ),
                    ),
                  ),
                  // Button fixed at bottom with safe spacing
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: StyledButton(
                              onPressed: _submitting ? null : _handleWithdrawal,
                              child: _submitting
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : PrimaryTextW('Withdrawal'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}