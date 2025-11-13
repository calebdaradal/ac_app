import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:ac_app/constants/transaction_constants.dart';
import 'package:ac_app/services/transaction_service.dart';
import 'package:ac_app/services/investment_service.dart';
import 'package:ac_app/services/yield_service.dart';
import 'package:ac_app/shared/styled_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../services/user_profile_service.dart';
import 'create_user_screen.dart';

class AdminScreen extends StatefulWidget {
  static const routeName = '/admin';
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<UserTransaction> _withdrawals = [];
  List<UserTransaction> _deposits = [];
  bool _loading = true;
  Set<int> _expandedCards = {};
  Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    try {
      final transactions = await TransactionService.getPendingTransactions();
      if (mounted) {
        setState(() {
          _withdrawals = transactions
              .where((t) => t.transactionId == TransactionType.withdrawal)
              .toList();
          _deposits = transactions
              .where((t) => t.transactionId == TransactionType.deposit)
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: '₱',
      decimalDigits: 2,
      locale: 'en_US',
    );
    return formatter.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  Future<DateTime?> _selectAppliedDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Applied Date',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppColors.titleColor,
            ),
          ),
          child: child!,
        );
      },
    );
    return picked;
  }

  Future<void> _approveTransaction(UserTransaction transaction) async {
    final isWithdrawal = transaction.transactionId == TransactionType.withdrawal;

    // Show date picker for admin to set applied date
    final appliedDate = await _selectAppliedDate();
    if (appliedDate == null) {
      // User cancelled date picker
      return;
    }

    setState(() => _processingIds.add(transaction.id));

    try {
      if (isWithdrawal) {
        // Process withdrawal
        final supabase = Supabase.instance.client;
        final userVehicle = await supabase
            .from('userinvestmentvehicle')
            .select('id, current_balance, total_contrib')
            .eq('user_uid', transaction.userUid)
            .eq('vehicle_id', transaction.vehicleId!)
            .maybeSingle();

        if (userVehicle == null) {
          throw Exception('User investment vehicle not found');
        }

        final currentBalance = (userVehicle['current_balance'] as num).toDouble();
        
        if (currentBalance < transaction.amount!) {
          throw Exception('Insufficient balance');
        }

        // Deduct ONLY from current_balance
        final newBalance = currentBalance - transaction.amount!;
        
        // Set total_contrib to equal new balance
        // Keep total_yield and total_yield_percent unchanged (only updated when admin applies yield)
        await supabase
            .from('userinvestmentvehicle')
            .update({
              'current_balance': newBalance,
              'total_contrib': newBalance, // Inherit from current_balance
              // total_yield and total_yield_percent remain unchanged
            })
            .eq('id', userVehicle['id']);

        await TransactionService.updateTransactionStatus(
          transactionId: transaction.id,
          status: TransactionStatus.issued,
        );
        await TransactionService.updateTransactionAppliedDate(
          transactionId: transaction.id,
          appliedDate: appliedDate,
        );
      } else {
        // Process deposit
        await InvestmentService.createDeposit(
          vehicleId: transaction.vehicleId!,
          amount: transaction.amount!,
          userUid: transaction.userUid,
        );

        await TransactionService.updateTransactionStatus(
          transactionId: transaction.id,
          status: TransactionStatus.verified,
        );
        await TransactionService.updateTransactionAppliedDate(
          transactionId: transaction.id,
          appliedDate: appliedDate,
        );
      }

      if (mounted) {
        setState(() {
          if (isWithdrawal) {
            _withdrawals.removeWhere((t) => t.id == transaction.id);
          } else {
            _deposits.removeWhere((t) => t.id == transaction.id);
          }
          _processingIds.remove(transaction.id);
          _expandedCards.remove(transaction.id);
        });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isWithdrawal ? "Withdrawal" : "Deposit"} approved successfully',
            ),
          backgroundColor: Colors.green,
        ),
      );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(transaction.id));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _denyTransaction(UserTransaction transaction) async {
    setState(() => _processingIds.add(transaction.id));

    try {
      await TransactionService.updateTransactionStatus(
        transactionId: transaction.id,
        status: TransactionStatus.denied,
      );

      if (mounted) {
        setState(() {
          if (transaction.transactionId == TransactionType.withdrawal) {
            _withdrawals.removeWhere((t) => t.id == transaction.id);
          } else {
            _deposits.removeWhere((t) => t.id == transaction.id);
          }
          _processingIds.remove(transaction.id);
          _expandedCards.remove(transaction.id);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction denied'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processingIds.remove(transaction.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTransactionCard(UserTransaction transaction) {
    final isExpanded = _expandedCards.contains(transaction.id);
    final isProcessing = _processingIds.contains(transaction.id);
    final isWithdrawal = transaction.transactionId == TransactionType.withdrawal;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCards.remove(transaction.id);
                } else {
                  _expandedCards.add(transaction.id);
                }
              });
            },
            borderRadius: isExpanded 
                ? const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  )
                : BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Expandable icon
                      Icon(
                        isExpanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TitleText(
                              transaction.fullName,
                              fontSize: 16,
                              color: AppColors.titleColor,
                            ),
                            const SizedBox(height: 4),
                            TitleText(
                              _formatCurrency(transaction.amount ?? 0),
                              fontSize: 20,
                              color: isWithdrawal ? Colors.red.shade700 : AppColors.primaryColor,
                            ),
                            const SizedBox(height: 4),
                            SecondaryText(
                              _formatDate(transaction.appliedAt),
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            if (!isWithdrawal && transaction.refNumber != null) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: PrimaryText(
                                  'Ref: ${transaction.refNumber}',
                                  fontSize: 12,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (!isProcessing) ...[
                        IconButton(
                          onPressed: () => _denyTransaction(transaction),
                          icon: Icon(Icons.close, color: Colors.red.shade700),
                          tooltip: 'Deny',
                        ),
                        IconButton(
                          onPressed: () => _approveTransaction(transaction),
                          icon: Icon(Icons.check, color: Colors.green.shade700),
                          tooltip: 'Approve',
                        ),
                      ] else ...[
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  
                  
                  TitleText('Bank Details', fontSize: 14, color: Colors.grey.shade700),
                  const SizedBox(height: 8),
                  if (transaction.bankName != null) ...[
                    _buildDetailRow('Bank Name', transaction.bankName ?? 'N/A'),
                    _buildDetailRow('Account Name', transaction.accountName ?? 'N/A'),
                    _buildDetailRow('Account Number', transaction.accountNumber ?? 'N/A'),
                    _buildDetailRow('Location', transaction.location ?? 'N/A'),
                    if (transaction.location == 'UK' && transaction.shortCode != null)
                      _buildDetailRow('Short Code', transaction.shortCode!),
                  ] else ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SecondaryText(
                          'No bank details available',
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: SecondaryText(label, fontSize: 13, color: Colors.grey.shade600),
          ),
          Expanded(
            child: PrimaryText(value, fontSize: 13, color: AppColors.titleColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: SecondaryText(
          message,
          fontSize: 14,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Future<void> _showYieldModal() async {
    InvestmentVehicle? selectedVehicle;
    String selectedYieldType = 'Amount';
    final yieldController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isSubmitting = false;
    List<InvestmentVehicle> vehicles = [];

    // Load vehicles
    try {
      vehicles = await YieldService.getAllVehicles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vehicles: $e')),
        );
      }
      return;
    }

    if (vehicles.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No investment vehicles found')),
        );
      }
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.percent_rounded, color: AppColors.primaryColor),
                  const SizedBox(width: 12),
                  const TitleText('Apply Yield', fontSize: 20),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vehicle Dropdown
                      const SecondaryText('Investment Vehicle', fontSize: 14),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(247, 249, 252, 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<InvestmentVehicle>(
                          value: selectedVehicle,
                          decoration: InputDecoration(
                            hintText: 'Select vehicle',
                            hintStyle: TextStyle(
                              color: AppColors.titleColor.withOpacity(0.5),
                            ),
                            filled: true,
                            fillColor: const Color.fromRGBO(247, 249, 252, 1),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          isExpanded: true,
                          items: vehicles.map((vehicle) {
                            return DropdownMenuItem<InvestmentVehicle>(
                              value: vehicle,
                              child: Text(
                                vehicle.vehicleName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedVehicle = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Yield Input with Type Dropdown
                      const SecondaryText('Yield Value', fontSize: 14),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(247, 249, 252, 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: yieldController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  hintText: selectedYieldType == 'Amount' ? 'Enter amount' : 'Enter %',
                                  hintStyle: TextStyle(
                                    color: AppColors.titleColor.withOpacity(0.5),
                                  ),
                                  filled: true,
                                  fillColor: const Color.fromRGBO(247, 249, 252, 1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(247, 249, 252, 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: selectedYieldType,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color.fromRGBO(247, 249, 252, 1),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                ),
                                items: ['Amount', 'Percentage'].map((type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(type == 'Amount' ? '₱' : '%'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedYieldType = value!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Date Picker
                      const SecondaryText('Applied Date', fontSize: 14),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(247, 249, 252, 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: AppColors.primaryColor, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('MMM dd, yyyy').format(selectedDate),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.titleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Info box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SecondaryText(
                                'Performance fee of 20% will be deducted from gross yield',
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () {
                    Navigator.pop(dialogContext);
                  },
                  child: SecondaryText(
                    'Cancel',
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                StyledButton(
                  onPressed: isSubmitting ? null : () async {
                    // Validate inputs
                    if (selectedVehicle == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a vehicle')),
                      );
                      return;
                    }

                    if (yieldController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter yield value')),
                      );
                      return;
                    }

                    final yieldValue = double.tryParse(yieldController.text.trim());
                    if (yieldValue == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid number')),
                      );
                      return;
                    }
                    
                    // For percentage type, validate range
                    if (selectedYieldType == 'Percentage' && (yieldValue < -100 || yieldValue > 100)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Percentage must be between -100% and 100%')),
                      );
                      return;
                    }

                    // Show confirmation dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const TitleText('Confirm Yield Application', fontSize: 18),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SecondaryText(
                              'Vehicle: ${selectedVehicle!.vehicleName}',
                              fontSize: 14,
                            ),
                            const SizedBox(height: 8),
                            SecondaryText(
                              'Yield: ${selectedYieldType == 'Amount' 
                                ? '${yieldValue >= 0 ? '₱' : '-₱'}${_formatCurrency(yieldValue.abs())}' 
                                : '${yieldValue >= 0 ? '+' : ''}$yieldValue%'}',
                              fontSize: 14,
                              color: yieldValue >= 0 ? null : Colors.red,
                            ),
                            const SizedBox(height: 8),
                            SecondaryText(
                              'Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                              fontSize: 14,
                            ),
                            const SizedBox(height: 16),
                            SecondaryText(
                              yieldValue < 0 
                                ? '⚠️ This is a NEGATIVE yield update. User balances will DECREASE.'
                                : 'This will update all user balances subscribed to this vehicle.',
                              fontSize: 13,
                              color: yieldValue < 0 ? Colors.red : Colors.orange,
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const SecondaryText('Cancel', fontSize: 14),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                            ),
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;

                    // Apply yield
                    setDialogState(() {
                      isSubmitting = true;
                    });

                    try {
                      final result = await YieldService.applyYield(
                        vehicleId: selectedVehicle!.id,
                        yieldValue: yieldValue,
                        yieldType: selectedYieldType,
                        appliedDate: selectedDate,
                      );

                      if (mounted) {
                        Navigator.pop(dialogContext);
                        
                        // Show success dialog
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 32),
                                const SizedBox(width: 12),
                                const TitleText('Yield Applied Successfully', fontSize: 18),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SecondaryText('Users Affected: ${result.usersAffected}', fontSize: 14),
                                const SizedBox(height: 8),
                                SecondaryText(
                                  'Total AUM: ₱${_formatCurrency(result.totalAum)}',
                                  fontSize: 14,
                                ),
                                const SizedBox(height: 8),
                                SecondaryText(
                                  'Total Gross Yield: ₱${_formatCurrency(result.totalGrossYield)}',
                                  fontSize: 14,
                                ),
                                const SizedBox(height: 8),
                                SecondaryText(
                                  'Total Performance Fee: ₱${_formatCurrency(result.totalPerformanceFee)}',
                                  fontSize: 14,
                                ),
                                const SizedBox(height: 8),
                                SecondaryText(
                                  'Net Distributed: ₱${_formatCurrency(result.totalGrossYield - result.totalPerformanceFee)}',
                                  fontSize: 14,
                                  color: Colors.green.shade700,
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryColor,
                                ),
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        isSubmitting = false;
                      });
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error applying yield: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Apply Yield'),
                ),
              ],
            );
          },
        );
      },
    );

    // Dispose controller after dialog animation completes
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        yieldController.dispose();
      } catch (e) {
        // Controller already disposed, ignore
        print('[YieldModal] Controller disposal: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = UserProfileService().profile;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 90,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        flexibleSpace: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 12, bottom: 12, right: 16),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  highlightColor: Colors.grey.withOpacity(0.5),
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8, right: 15),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 80,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            image: profile?.avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(profile!.avatarUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : DecorationImage(
                                    image: AssetImage('assets/img/sample/man.jpg'),
                                  ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TitleText(
                              profile?.fullName ?? 'Admin',
                              fontSize: 18,
                              color: AppColors.titleColor,
                            ),
                            PrimaryText(
                              profile?.email ?? '',
                              fontSize: 14,
                              color: AppColors.secondaryTextColor,
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(),
                ),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        _showYieldModal();
                      },
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                      highlightColor: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.percent_rounded, size: 29, color: AppColors.primaryColor),
                      ),
                    ),
                    
                    InkWell(
                      onTap: () {
                        Navigator.pushNamed(context, CreateUserScreen.routeName);
                      },
                      borderRadius: BorderRadius.all(Radius.circular(25)),
                      highlightColor: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Icon(Icons.person_add_alt_rounded, size: 29, color: AppColors.primaryColor),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTransactions,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                    // Withdrawals Section
                    TitleText('Withdrawals', fontSize: 20, color: AppColors.titleColor),
              const SizedBox(height: 12),
                    if (_withdrawals.isEmpty)
                      _buildEmptyState('No pending withdrawals')
                    else
                      ..._withdrawals.map((t) => _buildTransactionCard(t)).toList(),
                    
                    const SizedBox(height: 32),
                    
                    // Deposits Section
                    TitleText('Deposits', fontSize: 20, color: AppColors.titleColor),
              const SizedBox(height: 12),
                    if (_deposits.isEmpty)
                      _buildEmptyState('No pending deposits')
                    else
                      ..._deposits.map((t) => _buildTransactionCard(t)).toList(),
            ],
          ),
        ),
      ),
    );
  }
}
