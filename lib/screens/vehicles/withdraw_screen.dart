import 'package:ac_app/services/bank_details_service.dart';
import 'package:ac_app/services/transaction_service.dart';
import 'package:ac_app/services/user_profile_service.dart';
import 'package:ac_app/constants/transaction_constants.dart';
import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/styled_card.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/shared/styled_textfield.dart';
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
  double _totalAmount = 0.0;

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
      });
      return;
    }

    // Use shared fee calculation logic
    final feeCalc = TransactionService.calculateWithdrawalFee(
      withdrawalAmount: amount,
      currentBalance: _currentBalance!,
    );

    setState(() {
      _feeAmount = feeCalc['fee']!;
      _totalAmount = feeCalc['totalDeduction']!;
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

      // Show success message
      String message = 'Withdrawal submitted!';
      if (_feeAmount > 0) {
        message += '\nWithdrawal: ₱${amount.toStringAsFixed(2)}';
        message += '\nFee (5%): ₱${_feeAmount.toStringAsFixed(2)}';
        message += '\nTotal deduction: ₱${_totalAmount.toStringAsFixed(2)}';
      } else {
        message += '\nAmount: ₱${amount.toStringAsFixed(2)}';
      }
      message += '\nWaiting for admin verification.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.primaryColor,
          duration: const Duration(seconds: 5),
        ),
      );

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
      body: _loading
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
                            showBankDetailsModal(
                              context,
                              existingDetails: _bankDetails,
                              onSaved: _loadBankDetails,
                            );
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
                        SecondaryText(
                          'Withdrawals over 33.33% of balance incur a 5% fee',
                          fontSize: 14,
                          color: Colors.grey,
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
                        if (_feeAmount > 0 && _currentBalance != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      SecondaryText(
                                        'Withdrawal Amount:',
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                      SecondaryText(
                                        '₱${(_totalAmount - _feeAmount).toStringAsFixed(2)}',
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4.0),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      SecondaryText(
                                        'Fee (5%):',
                                        fontSize: 14,
                                        color: Colors.orange.shade700,
                                      ),
                                      SecondaryText(
                                        '₱${_feeAmount.toStringAsFixed(2)}',
                                        fontSize: 14,
                                        color: Colors.orange.shade700,
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16.0),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      TitleText(
                                        'Total Deduction:',
                                        fontSize: 16,
                                      ),
                                      TitleText(
                                        '₱${_totalAmount.toStringAsFixed(2)}',
                                        fontSize: 16,
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
    );
  }
}