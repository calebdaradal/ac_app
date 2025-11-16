import 'package:ac_app/constants/transaction_constants.dart';
import 'package:ac_app/services/transaction_service.dart';
import 'package:ac_app/services/investment_service.dart';
import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminVerificationScreen extends StatefulWidget {
  static const routeName = '/admin-verification';
  const AdminVerificationScreen({super.key});

  @override
  State<AdminVerificationScreen> createState() => _AdminVerificationScreenState();
}

class _AdminVerificationScreenState extends State<AdminVerificationScreen> {
  List<UserTransaction> _pendingTransactions = [];
  bool _loading = true;
  Set<int> _verifyingIds = {}; // Track which transactions are being verified

  @override
  void initState() {
    super.initState();
    _loadPendingTransactions();
  }

  Future<void> _loadPendingTransactions() async {
    setState(() => _loading = true);
    try {
      final transactions = await TransactionService.getPendingTransactions();
      if (mounted) {
        setState(() {
          _pendingTransactions = transactions;
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

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  String _formatCurrency(double amount) {
    // Format with thousands separator (commas)
    final formatter = NumberFormat.currency(
      symbol: '₱',
      decimalDigits: 2,
      locale: 'en_US',
    );
    return formatter.format(amount);
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

  Future<void> _verifyTransaction(int transactionId) async {
    // Find the transaction
    final transaction = _pendingTransactions.firstWhere(
      (t) => t.id == transactionId,
    );

    if (transaction.vehicleId == null || transaction.amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction missing required information (vehicle_id or amount)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check transaction type
    final isWithdrawal = transaction.transactionId == TransactionType.withdrawal;
    final isDeposit = transaction.transactionId == TransactionType.deposit;

    if (!isWithdrawal && !isDeposit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unknown transaction type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show date picker for admin to set applied date
    final appliedDate = await _selectAppliedDate();
    if (appliedDate == null) {
      // User cancelled date picker
      return;
    }

    setState(() => _verifyingIds.add(transactionId));

    try {
      if (isDeposit) {
        // Process deposit: add to investment vehicle balance
        await InvestmentService.createDeposit(
          vehicleId: transaction.vehicleId!,
          amount: transaction.amount!,
          userUid: transaction.userUid,
          appliedDate: appliedDate,
        );

        // Update transaction status to VERIFIED and applied_at date
        await TransactionService.updateTransactionStatus(
          transactionId: transactionId,
          status: TransactionStatus.verified,
        );
        await TransactionService.updateTransactionAppliedDate(
          transactionId: transactionId,
          appliedDate: appliedDate,
        );
      } else if (isWithdrawal) {
        // Process withdrawal: deduct from both current_balance and total_contrib
        final supabase = Supabase.instance.client;
        
        // Get current balance and total contrib
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
        
        // Validate sufficient balance
        if (currentBalance < transaction.amount!) {
          throw Exception(
            'Insufficient balance. Available: ${_formatCurrency(currentBalance)}, Required: ${_formatCurrency(transaction.amount!)}',
          );
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

        // Update transaction status to ISSUED and applied_at date
        await TransactionService.updateTransactionStatus(
          transactionId: transactionId,
          status: TransactionStatus.issued,
        );
        await TransactionService.updateTransactionAppliedDate(
          transactionId: transactionId,
          appliedDate: appliedDate,
        );
      }

      if (mounted) {
        // Remove from list
        setState(() {
          _pendingTransactions.removeWhere((t) => t.id == transactionId);
          _verifyingIds.remove(transactionId);
        });

        final action = isDeposit ? 'Deposit' : 'Withdrawal';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Transaction approved! $action of ${_formatCurrency(transaction.amount!)} processed successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _verifyingIds.remove(transactionId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing transaction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const TitleText('Verify Transactions', fontSize: 20),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.titleColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pendingTransactions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      TitleText(
                        'No Pending Transactions',
                        fontSize: 20,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      SecondaryText(
                        'All transactions have been processed',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPendingTransactions,
                  color: AppColors.primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _pendingTransactions[index];
                      final isVerifying = _verifyingIds.contains(transaction.id);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        color: const Color.fromARGB(255, 252, 252, 252),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with amount and date
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          // Transaction type indicator
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: transaction.transactionId == TransactionType.withdrawal
                                                  ? Colors.red.shade50
                                                  : Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  transaction.transactionId == TransactionType.withdrawal
                                                      ? Icons.arrow_upward
                                                      : Icons.arrow_downward,
                                                  size: 12,
                                                  color: transaction.transactionId == TransactionType.withdrawal
                                                      ? Colors.red.shade700
                                                      : Colors.green.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                PrimaryText(
                                                  transaction.transactionId == TransactionType.withdrawal
                                                      ? 'Withdrawal'
                                                      : 'Deposit',
                                                  fontSize: 11,
                                                  color: transaction.transactionId == TransactionType.withdrawal
                                                      ? Colors.red.shade700
                                                      : Colors.green.shade700,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TitleText(
                                        _formatCurrency(transaction.amount ?? 0),
                                        fontSize: 24,
                                        color: transaction.transactionId == TransactionType.withdrawal
                                            ? Colors.red.shade700
                                            : AppColors.primaryColor,
                                      ),
                                      const SizedBox(height: 4),
                                      SecondaryText(
                                        _formatDate(transaction.appliedAt),
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: PrimaryText(
                                      transaction.status ?? 'PENDING',
                                      fontSize: 12,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 16),
                              
                              // Bank Details
                              if (transaction.bankName != null || transaction.accountName != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SecondaryText(
                                      'Bank Details',
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 4),
                                    TitleText(
                                      transaction.bankName ?? 'N/A',
                                      fontSize: 16,
                                    ),
                                    if (transaction.accountName != null)
                                      PrimaryText(
                                        transaction.accountName!,
                                        fontSize: 14,
                                        color: AppColors.secondaryTextColor,
                                      ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              
                              // Transaction Type
                              if (transaction.transactionType != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SecondaryText(
                                      'Type',
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(height: 4),
                                    PrimaryText(
                                      transaction.transactionType!,
                                      fontSize: 14,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              
                              // User Name (for admin reference)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SecondaryText(
                                    'User',
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  PrimaryText(
                                    transaction.fullName,
                                    fontSize: 14,
                                    color: AppColors.titleColor,
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Verify Button
                              Row(
                                children: [
                                  Expanded(
                                    child: PrimaryButton(
                                      onPressed: isVerifying
                                          ? null
                                          : () => _verifyTransaction(transaction.id),
                                      child: isVerifying
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : PrimaryTextW(
                                              transaction.transactionId == TransactionType.withdrawal
                                                  ? 'Approve Withdrawal'
                                                  : 'Verify Deposit',
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

