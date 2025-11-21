import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:ac_app/constants/transaction_constants.dart';
import 'package:ac_app/services/transaction_service.dart';
import 'package:ac_app/services/transaction_history_service.dart';
import 'package:ac_app/services/investment_service.dart';
import 'package:ac_app/services/yield_service.dart';
import 'package:ac_app/services/deposit_service.dart';
import 'package:ac_app/services/withdrawal_service.dart';
import 'package:ac_app/services/avatar_service.dart';
import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/styled_textfield.dart';
import 'package:ac_app/shared/styled_card.dart';
import 'package:ac_app/shared/success_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:typed_data';
import '../services/user_profile_service.dart';
import 'create_user_screen.dart';

enum TransactionFilter {
  dateAscending,
  dateDescending,
}

enum UserTransactionType {
  all,
  yields,
  transactions,
  pending,
}

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
  String _currentView = 'transactions'; // 'transactions' or 'manage_users'
  
  // Manage Users state
  List<UserProfile> _allUsers = [];
  UserProfile? _selectedUser;
  bool _isLoadingUsers = false;
  bool _isTogglingUserStatus = false;
  bool _isLoadingTransactions = false;
  List<TransactionHistoryItem> _userTransactions = [];
  List<TransactionHistoryItem> _filteredUserTransactions = [];
  TransactionFilter _currentUserFilter = TransactionFilter.dateDescending;
  UserTransactionType _selectedUserType = UserTransactionType.all;
  List<InvestmentVehicle> _allVehicles = [];
  InvestmentVehicle? _selectedVehicle;
  bool _isLoadingVehicles = false;
  bool _isLoadingUserStats = false;
  double _userCurrentBalance = 0.0;
  double _userTotalContributions = 0.0;
  double _userTotalYield = 0.0;
  final ImagePicker _imagePicker = ImagePicker();
  final AvatarService _avatarService = AvatarService();
  
  // Vehicle selection for user management
  List<InvestmentVehicle> _userVehicles = [];
  InvestmentVehicle? _selectedUserVehicle;
  UserVehicleSubscription? _selectedUserSubscription;
  bool _isLoadingUserSubscription = false;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    super.dispose();
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
      symbol: '',
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
    // Validate required fields
    if (transaction.vehicleId == null || transaction.amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction missing required information (vehicle_id or amount)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
        await supabase
            .from('userinvestmentvehicle')
            .update({
              'current_balance': newBalance,
              'total_contrib': newBalance, // Inherit from current_balance
            })
            .eq('id', userVehicle['id']);

        // Update transaction status and date together (prevents duplicate webhook triggers)
        await TransactionService.updateTransactionStatusAndDate(
          transactionId: transaction.id,
          status: TransactionStatus.issued,
          appliedDate: appliedDate,
        );
      } else {
        // Process deposit
        await InvestmentService.createDeposit(
          vehicleId: transaction.vehicleId!,
          amount: transaction.amount!,
          userUid: transaction.userUid,
          appliedDate: appliedDate,
        );

        // Update transaction status and date together (prevents duplicate webhook triggers)
        await TransactionService.updateTransactionStatusAndDate(
          transactionId: transaction.id,
          status: TransactionStatus.verified,
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
      
      // Refresh user stats and transactions if viewing this user
      if (_selectedUser != null && _selectedUser!.uid == transaction.userUid) {
        await Future.wait([
          _loadUserStats(_selectedUser!.uid, vehicleId: _selectedVehicle?.id),
          _loadUserTransactions(_selectedUser!.uid, vehicleId: _selectedVehicle?.id),
        ]);
      }
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

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
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
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color ?? AppColors.titleColor,
              ),
            ),
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
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
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
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.transparent,
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
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.transparent,
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
                        
                        // Refresh user stats and transactions if viewing a user and yield affects their vehicle
                        if (_selectedUser != null && _selectedVehicle != null && _selectedVehicle!.id == selectedVehicle!.id) {
                          await Future.wait([
                            _loadUserStats(_selectedUser!.uid, vehicleId: _selectedVehicle?.id),
                            _loadUserTransactions(_selectedUser!.uid, vehicleId: _selectedVehicle?.id),
                          ]);
                        }
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

  Future<void> _showPersonalYieldDialog(UserProfile user) async {
    InvestmentVehicle? selectedVehicle;
    String selectedYieldType = 'Amount';
    final yieldController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isSubmitting = false;
    List<InvestmentVehicle> vehicles = [];

    // Load user's vehicles
    try {
      vehicles = await YieldService.getUserVehicles(user.uid);
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
          SnackBar(content: Text('${user.fullName} is not subscribed to any vehicles')),
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
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: Row(
                children: [
                  Icon(Icons.person, color: AppColors.primaryColor),
                  const SizedBox(width: 12),
                  const TitleText('Apply Personal Yield', fontSize: 20),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User info
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
                                'Applying yield to: ${user.fullName} (${user.email})',
                                fontSize: 12,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

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
                                'Performance fee of 20% will be deducted from gross yield. This yield will only apply to ${user.fullName}.',
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
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        title: const TitleText('Confirm Personal Yield', fontSize: 18),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SecondaryText(
                              'User: ${user.fullName}',
                              fontSize: 14,
                            ),
                            const SizedBox(height: 8),
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
                                ? '⚠️ This is a NEGATIVE yield update. ${user.fullName}\'s balance will DECREASE.'
                                : 'This will update ${user.fullName}\'s balance for this vehicle only.',
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

                    // Apply personal yield
                    setDialogState(() {
                      isSubmitting = true;
                    });

                    try {
                      final result = await YieldService.applyPersonalYield(
                        userUid: user.uid,
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
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.transparent,
                            title: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 32),
                                const SizedBox(width: 12),
                                const TitleText('Personal Yield Applied', fontSize: 18),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SecondaryText('User: ${user.fullName}', fontSize: 14),
                                const SizedBox(height: 8),
                                SecondaryText(
                                  'Total AUM: ₱${_formatCurrency(result.totalAum)}',
                                  fontSize: 14,
                                ),
                                const SizedBox(height: 8),
                                SecondaryText(
                                  'Gross Yield: ₱${_formatCurrency(result.totalGrossYield)}',
                                  fontSize: 14,
                                ),
                                const SizedBox(height: 8),
                                SecondaryText(
                                  'Performance Fee: ₱${_formatCurrency(result.totalPerformanceFee)}',
                                  fontSize: 14,
                                ),
                                const SizedBox(height: 8),
                                SecondaryText(
                                  'Net Yield: ₱${_formatCurrency(result.totalGrossYield - result.totalPerformanceFee)}',
                                  fontSize: 14,
                                  color: Colors.green.shade700,
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  // Reload user transactions to show updated balance
                                  if (_selectedUser?.uid == user.uid) {
                                    if (_selectedUserVehicle != null) {
                                      await _loadUserSubscriptionData(user.uid, _selectedUserVehicle!.id);
                                      await _loadUserTransactions(user.uid, _selectedUserVehicle!.id);
                                    }
                                  }
                                },
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
                            content: Text('Error applying personal yield: $e'),
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
        print('[PersonalYieldModal] Controller disposal: $e');
      }
    });
  }

  Future<void> _showDepositModal() async {
    UserProfile? selectedUser;
    int? selectedVehicleId;
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isSubmitting = false;
    List<UserProfile> users = [];

    // Load users
    try {
      users = await DepositService.getAllUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
      return;
    }

    if (users.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No users found')),
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
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: AppColors.primaryColor),
                  const SizedBox(width: 12),
                  const TitleText('Apply Deposit', fontSize: 20),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Dropdown
                      const SecondaryText('User', fontSize: 14),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(247, 249, 252, 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<UserProfile>(
                          value: selectedUser,
                          decoration: InputDecoration(
                            hintText: 'Select user',
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
                          items: users.map((user) {
                            final displayText = user.fullName != 'User' 
                                ? '${user.fullName} (${user.email})' 
                                : user.email;
                            return DropdownMenuItem<UserProfile>(
                              value: user,
                              child: Text(
                                displayText,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedUser = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Vehicle Dropdown
                      const SecondaryText('Investment Vehicle', fontSize: 14),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(247, 249, 252, 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<int>(
                          value: selectedVehicleId,
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
                          items: [
                            DropdownMenuItem<int>(
                              value: 1,
                              child: Text('Ascendo Futures Fund'),
                            ),
                            DropdownMenuItem<int>(
                              value: 2,
                              child: Text('SOL/ETH Staking Pool'),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedVehicleId = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount Input
                      const SecondaryText('Deposit Amount', fontSize: 14),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(247, 249, 252, 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: 'Enter amount',
                            prefixText: '₱ ',
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
                    if (selectedUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a user')),
                      );
                      return;
                    }

                    if (selectedVehicleId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a vehicle')),
                      );
                      return;
                    }

                    if (amountController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter deposit amount')),
                      );
                      return;
                    }

                    final amount = double.tryParse(amountController.text.trim());
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount greater than zero')),
                      );
                      return;
                    }

                    // Show confirmation dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const TitleText('Confirm Deposit Application', fontSize: 18),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SecondaryText(
                              'User: ${selectedUser!.fullName}',
                              fontSize: 14,
                            ),
                            const SizedBox(height: 8),
                            SecondaryText(
                              'Vehicle: ${selectedVehicleId == 1 ? 'Ascendo Futures Fund' : 'SOL/ETH Staking Pool'}',
                              fontSize: 14,
                            ),
                            const SizedBox(height: 8),
                            SecondaryText(
                              'Amount: ₱${_formatCurrency(amount)}',
                              fontSize: 14,
                            ),
                            const SizedBox(height: 8),
                            SecondaryText(
                              'Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                              fontSize: 14,
                            ),
                            const SizedBox(height: 16),
                            SecondaryText(
                              'This will create a deposit transaction for the selected user.',
                              fontSize: 13,
                              color: Colors.orange,
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

                    // Apply deposit
                    setDialogState(() {
                      isSubmitting = true;
                    });

                    try {
                      await DepositService.applyDeposit(
                        userUid: selectedUser!.uid,
                        vehicleId: selectedVehicleId!,
                        amount: amount,
                        appliedDate: selectedDate,
                      );

                      if (mounted) {
                        Navigator.pop(dialogContext);
                        
                        // Show success dialog
                        await showSuccessDialog(
                          context,
                          'Deposit applied successfully!\n\nUser: ${selectedUser!.fullName}\nVehicle: ${selectedVehicleId == 1 ? 'Ascendo Futures Fund' : 'SOL/ETH Staking Pool'}\nAmount: ₱${_formatCurrency(amount)}',
                        );
                        
                        // Refresh transactions
                        _loadTransactions();
                        
                        // Refresh user stats and transactions if viewing this user
                        if (_selectedUser != null && _selectedUser!.uid == selectedUser!.uid) {
                          await Future.wait([
                            _loadUserStats(_selectedUser!.uid, vehicleId: _selectedVehicle?.id),
                            _loadUserTransactions(_selectedUser!.uid, vehicleId: _selectedVehicle?.id),
                          ]);
                        }
                      }
                    } catch (e) {
                      setDialogState(() {
                        isSubmitting = false;
                      });
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error applying deposit: $e'),
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
                      : const Text('Apply Deposit'),
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
        amountController.dispose();
      } catch (e) {
        // Controller already disposed, ignore
        print('[DepositModal] Controller disposal: $e');
      }
    });
  }

  Future<void> _showWithdrawModal() async {
    UserProfile? selectedUser;
    int? selectedVehicleId;
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    bool isSubmitting = false;
    List<UserProfile> users = [];
    double? currentBalance;
    bool isLoadingBalance = false;

    // Load users with contributions > 0
    try {
      users = await WithdrawalService.getUsersWithContributions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
      return;
    }

    if (users.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No users with contributions found')),
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
            // Function to load balance when user/vehicle changes
            Future<void> loadBalance() async {
              if (selectedUser == null || selectedVehicleId == null) {
                return;
              }
              
              setDialogState(() {
                isLoadingBalance = true;
              });

              try {
                final balance = await WithdrawalService.getCurrentBalance(
                  userUid: selectedUser!.uid,
                  vehicleId: selectedVehicleId!,
                );
                setDialogState(() {
                  currentBalance = balance;
                  isLoadingBalance = false;
                });
              } catch (e) {
                setDialogState(() {
                  currentBalance = null;
                  isLoadingBalance = false;
                });
              }
            }
            // Calculate fee and total withdrawal in real-time
            double withdrawalAmount = 0.0;
            double feeAmount = 0.0;
            double totalWithdrawal = 0.0;
            
            if (amountController.text.isNotEmpty) {
              final parsedAmount = double.tryParse(amountController.text.trim());
              if (parsedAmount != null && parsedAmount > 0) {
                withdrawalAmount = (parsedAmount * 100).round() / 100.0;
                
                if (currentBalance != null && currentBalance! > 0) {
                  final threshold = currentBalance! * 0.3333;
                  if (withdrawalAmount > threshold) {
                    feeAmount = (withdrawalAmount * 0.05 * 100).round() / 100.0;
                  }
                  totalWithdrawal = (withdrawalAmount + feeAmount) * 100;
                  totalWithdrawal = totalWithdrawal.round() / 100.0;
                }
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: Colors.red.shade700),
                  const SizedBox(width: 12),
                  const TitleText('Apply Withdrawal', fontSize: 20),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Dropdown
                      const SecondaryText('User', fontSize: 14),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(247, 249, 252, 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<UserProfile>(
                          value: selectedUser,
                          decoration: InputDecoration(
                            hintText: 'Select user',
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
                          items: users.map((user) {
                            final displayText = user.fullName != 'User' 
                                ? '${user.fullName} (${user.email})' 
                                : user.email;
                            return DropdownMenuItem<UserProfile>(
                              value: user,
                              child: Text(
                                displayText,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() {
                              selectedUser = value;
                              selectedVehicleId = null; // Reset vehicle when user changes
                              currentBalance = null;
                              amountController.clear();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Vehicle Dropdown
                      const SecondaryText('Investment Vehicle', fontSize: 14),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(247, 249, 252, 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<int>(
                          value: selectedVehicleId,
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
                          items: [
                            DropdownMenuItem<int>(
                              value: 1,
                              child: Text('Ascendo Futures Fund'),
                            ),
                            DropdownMenuItem<int>(
                              value: 2,
                              child: Text('SOL/ETH Staking Pool'),
                            ),
                          ],
                          onChanged: selectedUser == null ? null : (value) {
                            setDialogState(() {
                              selectedVehicleId = value;
                              currentBalance = null;
                              amountController.clear();
                            });
                            loadBalance();
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Current Balance Display
                      if (selectedUser != null && selectedVehicleId != null) ...[
                        if (isLoadingBalance)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                SecondaryText('Loading balance...', fontSize: 14),
                              ],
                            ),
                          )
                        else if (currentBalance != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.account_balance_wallet, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SecondaryText(
                                        'Current Balance',
                                        fontSize: 12,
                                        color: Colors.blue.shade900,
                                      ),
                                      TitleText(
                                        _formatCurrency(currentBalance!),
                                        fontSize: 16,
                                        color: Colors.blue.shade900,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],

                      // Amount Input
                      const SecondaryText('Withdrawal Amount', fontSize: 14),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(247, 249, 252, 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (value) {
                            setDialogState(() {}); // Trigger rebuild to update fee calculation
                          },
                          decoration: InputDecoration(
                            hintText: 'Enter amount',
                            prefixText: '₱ ',
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
                      
                      // Real-time Fee and Total Display
                      if (withdrawalAmount > 0 && currentBalance != null && currentBalance! > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: feeAmount > 0 ? Colors.orange.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: feeAmount > 0 ? Colors.orange.shade200 : Colors.green.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    feeAmount > 0 ? Icons.warning_amber_rounded : Icons.info_outline,
                                    color: feeAmount > 0 ? Colors.orange.shade700 : Colors.green.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SecondaryText(
                                      feeAmount > 0 
                                          ? '5% fee applies (withdrawal > 33.33% of balance)'
                                          : 'No fee (withdrawal ≤ 33.33% of balance)',
                                      fontSize: 12,
                                      color: feeAmount > 0 ? Colors.orange.shade900 : Colors.green.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow('Withdrawal Amount', _formatCurrency(withdrawalAmount)),
                              if (feeAmount > 0)
                                _buildDetailRow('Fee (5%)', _formatCurrency(feeAmount)),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  SecondaryText('Total Deduction', fontSize: 13, color: Colors.grey.shade600),
                                  Text(
                                    _formatCurrency(totalWithdrawal),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              if (currentBalance != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    SecondaryText('Balance After', fontSize: 13, color: Colors.grey.shade600),
                                    Text(
                                      _formatCurrency(currentBalance! - totalWithdrawal),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

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
                    if (selectedUser == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a user')),
                      );
                      return;
                    }

                    if (selectedVehicleId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please select a vehicle')),
                      );
                      return;
                    }

                    if (amountController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter withdrawal amount')),
                      );
                      return;
                    }

                    final amount = double.tryParse(amountController.text.trim());
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid amount greater than zero')),
                      );
                      return;
                    }

                    if (currentBalance == null || currentBalance! <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Unable to load user balance')),
                      );
                      return;
                    }

                    if (totalWithdrawal > currentBalance!) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Insufficient balance. Available: ${_formatCurrency(currentBalance!)}, Required: ${_formatCurrency(totalWithdrawal)}')),
                      );
                      return;
                    }

                    // Show confirmation dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        surfaceTintColor: Colors.transparent,
                        title: const TitleText('Confirm Withdrawal Application', fontSize: 18),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SecondaryText(
                              'User: ${selectedUser!.fullName}',
                              fontSize: 14,
                            ),
                            const SizedBox(height: 8),
                            SecondaryText(
                              'Vehicle: ${selectedVehicleId == 1 ? 'Ascendo Futures Fund' : 'SOL/ETH Staking Pool'}',
                              fontSize: 14,
                            ),
                            const SizedBox(height: 8),
                            SecondaryText(
                              'Withdrawal: ₱${_formatCurrency(withdrawalAmount)}',
                              fontSize: 14,
                            ),
                            if (feeAmount > 0) ...[
                              const SizedBox(height: 8),
                              SecondaryText(
                                'Fee (5%): ₱${_formatCurrency(feeAmount)}',
                                fontSize: 14,
                                color: Colors.orange,
                              ),
                            ],
                            const SizedBox(height: 8),
                            SecondaryText(
                              'Total Deduction: ₱${_formatCurrency(totalWithdrawal)}',
                              fontSize: 14,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(height: 8),
                            SecondaryText(
                              'Date: ${DateFormat('MMM dd, yyyy').format(selectedDate)}',
                              fontSize: 14,
                            ),
                            const SizedBox(height: 16),
                            SecondaryText(
                              '⚠️ This will reset the user\'s yield to 0 and update their balance.',
                              fontSize: 13,
                              color: Colors.orange,
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
                              backgroundColor: Colors.red.shade700,
                            ),
                            child: const Text('Confirm'),
                          ),
                        ],
                      ),
                    );

                    if (confirm != true) return;

                    // Apply withdrawal
                    setDialogState(() {
                      isSubmitting = true;
                    });

                    try {
                      await WithdrawalService.applyWithdrawal(
                        userUid: selectedUser!.uid,
                        vehicleId: selectedVehicleId!,
                        amount: withdrawalAmount,
                        appliedDate: selectedDate,
                      );

                      if (mounted) {
                        Navigator.pop(dialogContext);
                        
                        // Show success dialog
                        String successMessage = 'Withdrawal applied successfully!\n\n';
                        successMessage += 'User: ${selectedUser!.fullName}\n';
                        successMessage += 'Vehicle: ${selectedVehicleId == 1 ? 'Ascendo Futures Fund' : 'SOL/ETH Staking Pool'}\n';
                        successMessage += 'Withdrawal: ₱${_formatCurrency(withdrawalAmount)}\n';
                        if (feeAmount > 0) {
                          successMessage += 'Fee: ₱${_formatCurrency(feeAmount)}\n';
                        }
                        successMessage += 'Total: ₱${_formatCurrency(totalWithdrawal)}';
                        
                        await showSuccessDialog(context, successMessage);
                        
                        // Refresh transactions
                        _loadTransactions();
                        
                        // Refresh user stats and transactions if viewing this user
                        if (_selectedUser != null && _selectedUser!.uid == selectedUser!.uid) {
                          await Future.wait([
                            _loadUserStats(_selectedUser!.uid, vehicleId: _selectedVehicle?.id),
                            _loadUserTransactions(_selectedUser!.uid, vehicleId: _selectedVehicle?.id),
                          ]);
                        }
                      }
                    } catch (e) {
                      setDialogState(() {
                        isSubmitting = false;
                      });
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error applying withdrawal: $e'),
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
                      : const Text('Apply Withdrawal'),
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
        amountController.dispose();
      } catch (e) {
        // Controller already disposed, ignore
        print('[WithdrawModal] Controller disposal: $e');
      }
    });
  }


  @override
  Widget build(BuildContext context) {
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
                IconButton(
                  icon: Icon(Icons.arrow_back, color: AppColors.titleColor),
                  onPressed: () {
                    if (_currentView == 'manage_users') {
                      setState(() {
                        _currentView = 'transactions';
                        // Reset selection when going back to transactions
                        _selectedUser = null;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                Expanded(
                  child: SizedBox(),
                ),
                Theme(
                  data: Theme.of(context).copyWith(
                    popupMenuTheme: PopupMenuThemeData(
                      color: AppColors.secondaryColor,
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    icon: Icon(Icons.menu, color: AppColors.titleColor, size: 28),
                    onSelected: (value) {
                      switch (value) {
                        case 'yield':
                          _showYieldModal();
                          break;
                        case 'deposit':
                          _showDepositModal();
                          break;
                        case 'withdraw':
                          _showWithdrawModal();
                          break;
                        case 'create_user':
                          Navigator.pushNamed(context, CreateUserScreen.routeName);
                          break;
                        case 'manage_users':
                          _switchToManageUsers();
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<String>(
                        value: 'yield',
                        child: Row(
                          children: [
                            Icon(Icons.percent_rounded, color: AppColors.primaryColor, size: 20),
                            const SizedBox(width: 12),
                            const Text('Apply Yield'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'deposit',
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: AppColors.primaryColor, size: 20),
                            const SizedBox(width: 12),
                            const Text('Apply Deposit'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'withdraw',
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 12),
                            const Text('Apply Withdraw'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'create_user',
                        child: Row(
                          children: [
                            Icon(Icons.person_add_alt_rounded, color: AppColors.primaryColor, size: 20),
                            const SizedBox(width: 12),
                            const Text('Create new User'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'manage_users',
                        child: Row(
                          children: [
                            Icon(Icons.people, color: AppColors.primaryColor, size: 20),
                            const SizedBox(width: 12),
                            const Text('Manage Users'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _currentView == 'manage_users'
              ? _buildManageUsersView()
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

  Future<void> _switchToManageUsers() async {
    setState(() {
      _currentView = 'manage_users';
      // Reset selection when switching to manage users view
      _selectedUser = null;
    });
    await _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final users = await DepositService.getAllUsers();
      if (mounted) {
        // Sort users: active users first, then disabled users at the bottom
        final sortedUsers = List<UserProfile>.from(users);
        sortedUsers.sort((a, b) {
          // Active users (isActive == true or null) come first
          final aActive = a.isActive;
          final bActive = b.isActive;
          
          if (aActive == false && bActive != false) {
            return 1; // a is disabled, b is active - a goes after b
          } else if (aActive != false && bActive == false) {
            return -1; // a is active, b is disabled - a goes before b
          }
          // Both same status - sort alphabetically by first name
          final aName = (a.firstName ?? '').toLowerCase();
          final bName = (b.firstName ?? '').toLowerCase();
          return aName.compareTo(bName);
        });
        
        // If a user was previously selected, try to find it in the new list by uid
        String? previousUid = _selectedUser?.uid;
        
        setState(() {
          _allUsers = sortedUsers;
          _isLoadingUsers = false;
          
            // If we had a selected user, try to find it in the new list
            if (previousUid != null) {
              final matchingUser = sortedUsers.firstWhere(
                (u) => u.uid == previousUid,
                orElse: () => _selectedUser!,
              );
              // Only update if it's actually a different instance
              if (matchingUser.uid == previousUid) {
                _selectedUser = matchingUser;
              } else {
                // User not found in new list, reset selection
                _selectedUser = null;
              }
            }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingUsers = false;
          // Reset selection on error
          _selectedUser = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    }
  }

  Future<void> _onUserSelected(UserProfile? user) async {
    if (user == null) {
      setState(() {
        _selectedUser = null;
        _userTransactions = [];
<<<<<<< HEAD
        _userVehicles = [];
        _selectedUserVehicle = null;
        _selectedUserSubscription = null;
=======
        _selectedVehicle = null;
>>>>>>> refs/remotes/origin/master
      });
      return;
    }

    setState(() {
      _selectedUser = user;
      _userTransactions = [];
<<<<<<< HEAD
      _userVehicles = [];
      _selectedUserVehicle = null;
      _selectedUserSubscription = null;
    });
    
    // Load user's vehicles
    try {
      final vehicles = await YieldService.getUserVehicles(user.uid);
      if (mounted && vehicles.isNotEmpty) {
        final firstVehicle = vehicles.first;
        setState(() {
          _userVehicles = vehicles;
          _selectedUserVehicle = firstVehicle; // Use vehicle from the list
        });
        // Load subscription data and transactions for first vehicle
        await _loadUserSubscriptionData(user.uid, firstVehicle.id);
        await _loadUserTransactions(user.uid, firstVehicle.id);
      } else if (mounted) {
        setState(() {
          _userVehicles = [];
          _selectedUserVehicle = null;
        });
      }
    } catch (e) {
      print('[AdminScreen] Error loading user vehicles: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading vehicles: $e')),
        );
      }
    }
  }

  Future<void> _loadUserSubscriptionData(String userId, int vehicleId) async {
    setState(() => _isLoadingUserSubscription = true);
    try {
      final supabase = Supabase.instance.client;
      final subscriptionResponse = await supabase
          .from('userinvestmentvehicle')
          .select('id, vehicle_id, registered_at, total_contrib, current_balance')
          .eq('user_uid', userId)
          .eq('vehicle_id', vehicleId)
          .maybeSingle();
      
      if (subscriptionResponse != null) {
        // Get yield distributions to check if user has yields
        final hasYieldDistributions = await supabase
            .from('user_yield_distributions')
            .select('id')
            .eq('user_uid', userId)
            .eq('vehicle_id', vehicleId)
            .limit(1)
            .maybeSingle();

        final totalContrib = (subscriptionResponse['total_contrib'] as num).toDouble();
        final currentBalance = (subscriptionResponse['current_balance'] as num?)?.toDouble() ?? 0.0;
        final totalYield = currentBalance - totalContrib;

        // Get vehicle name
        final vehicleName = _selectedUserVehicle?.vehicleName ?? '';

        if (mounted) {
          setState(() {
            _selectedUserSubscription = UserVehicleSubscription(
              vehicleId: vehicleId,
              vehicleName: vehicleName,
              subscriptionId: subscriptionResponse['id'] as int,
              isSubscribed: true,
              totalContributions: totalContrib,
              currentBalance: currentBalance,
              totalYield: totalYield,
              hasYieldDistributions: hasYieldDistributions != null,
            );
            _isLoadingUserSubscription = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedUserSubscription = null;
            _isLoadingUserSubscription = false;
          });
        }
      }
    } catch (e) {
      print('[AdminScreen] Error loading subscription data: $e');
      if (mounted) {
        setState(() {
          _selectedUserSubscription = null;
          _isLoadingUserSubscription = false;
=======
      _selectedVehicle = null;
      _userCurrentBalance = 0.0;
      _userTotalContributions = 0.0;
      _userTotalYield = 0.0;
    });
    
    // Load vehicles, transaction history, and stats for selected user
    await _loadVehicles();
    await Future.wait([
      _loadUserTransactions(user.uid),
      _loadUserStats(user.uid),
    ]);
  }

  Future<void> _loadUserStats(String userId, {int? vehicleId}) async {
    setState(() => _isLoadingUserStats = true);
    
    try {
      final supabase = Supabase.instance.client;
      
      // Query userinvestmentvehicle - filter by vehicle if selected
      var subscriptionsQuery = supabase
          .from('userinvestmentvehicle')
          .select('total_contrib, current_balance, vehicle_id')
          .eq('user_uid', userId);
      
      if (vehicleId != null) {
        subscriptionsQuery = subscriptionsQuery.eq('vehicle_id', vehicleId);
      }
      
      final subscriptions = await subscriptionsQuery;
      
      double totalContrib = 0.0;
      double currentBalance = 0.0;
      
      // Sum up values across all vehicles (or single vehicle if selected)
      for (var sub in subscriptions) {
        totalContrib += (sub['total_contrib'] as num?)?.toDouble() ?? 0.0;
        currentBalance += (sub['current_balance'] as num?)?.toDouble() ?? 0.0;
      }
      
      // Calculate total yield: current_balance - total_contrib
      final totalYield = currentBalance - totalContrib;
      
      if (mounted) {
        setState(() {
          _userCurrentBalance = currentBalance;
          _userTotalContributions = totalContrib;
          _userTotalYield = totalYield;
          _isLoadingUserStats = false;
        });
      }
    } catch (e) {
      print('[AdminScreen] Error loading user stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserStats = false;
>>>>>>> refs/remotes/origin/master
        });
      }
    }
  }

<<<<<<< HEAD
  Future<void> _loadUserTransactions(String userId, int? vehicleId) async {
=======
  Future<void> _loadVehicles() async {
    setState(() => _isLoadingVehicles = true);
    try {
      final vehicles = await YieldService.getAllVehicles();
      if (mounted) {
        setState(() {
          _allVehicles = vehicles;
          _isLoadingVehicles = false;
        });
      }
    } catch (e) {
      print('[AdminScreen] Error loading vehicles: $e');
      if (mounted) {
        setState(() => _isLoadingVehicles = false);
      }
    }
  }

  Future<void> _onVehicleSelected(InvestmentVehicle? vehicle) async {
    setState(() {
      _selectedVehicle = vehicle;
    });
    
    // Reload transactions and stats filtered by selected vehicle
    if (_selectedUser != null) {
      await Future.wait([
        _loadUserTransactions(_selectedUser!.uid, vehicleId: vehicle?.id),
        _loadUserStats(_selectedUser!.uid, vehicleId: vehicle?.id),
      ]);
    }
  }

  Future<void> _loadUserTransactions(String userId, {int? vehicleId}) async {
>>>>>>> refs/remotes/origin/master
    setState(() => _isLoadingTransactions = true);
    
    try {
      final supabase = Supabase.instance.client;
      List<TransactionHistoryItem> allTransactions = [];
      
<<<<<<< HEAD
      // Fetch user transactions (deposits and withdrawals) for specific vehicle
      var query = supabase
=======
      // Fetch user transactions (deposits and withdrawals) - filter by vehicle if selected
      var userTransactionsQuery = supabase
>>>>>>> refs/remotes/origin/master
          .from('usertransactions')
          .select('id, transaction_id, amount, status, applied_at, created_at, vehicle_id')
          .eq('user_uid', userId);
      
      if (vehicleId != null) {
<<<<<<< HEAD
        query = query.eq('vehicle_id', vehicleId);
      }
      
      final userTransactionsResponse = await query;
=======
        userTransactionsQuery = userTransactionsQuery.eq('vehicle_id', vehicleId);
      }
      
      final userTransactionsResponse = await userTransactionsQuery;
>>>>>>> refs/remotes/origin/master
      
      for (var trans in userTransactionsResponse) {
        final transactionTypeId = trans['transaction_id'] as int;
        final status = trans['status'] as String;
        final amount = (trans['amount'] as num).toDouble();
        final appliedAt = DateTime.parse(trans['applied_at'] as String);
        final createdAtStr = trans['created_at'] as String?;
        
        String type;
        String displayStatus;
        
        if (transactionTypeId == 2) {
          type = 'Deposit';
          if (status == 'PENDING') {
            displayStatus = 'Verifying';
          } else if (status == 'DENIED') {
            displayStatus = 'Denied';
          } else if (status == 'VERIFIED') {
            displayStatus = 'Verified';
          } else {
            displayStatus = status;
          }
        } else {
          type = 'Withdrawal';
          if (status == 'PENDING') {
            displayStatus = 'Verifying';
          } else if (status == 'ISSUED') {
            displayStatus = 'Completed';
          } else if (status == 'DENIED') {
            displayStatus = 'Denied';
          } else {
            displayStatus = status;
          }
        }
        
        DateTime actionDate;
        if (createdAtStr != null && createdAtStr.isNotEmpty) {
          try {
            actionDate = DateTime.parse(createdAtStr);
          } catch (e) {
            actionDate = appliedAt;
          }
        } else {
          actionDate = appliedAt;
        }
        
        allTransactions.add(TransactionHistoryItem(
          id: trans['id'] as int,
          type: type,
          amount: amount,
          yieldPercent: null,
          status: displayStatus,
          date: appliedAt,
          actionDate: actionDate,
          isPositive: type == 'Deposit',
        ));
      }
      
<<<<<<< HEAD
      // Fetch yield distributions for specific vehicle
      var yieldQuery = supabase
=======
      // Fetch yield distributions - filter by vehicle if selected
      var yieldDistributionsQuery = supabase
>>>>>>> refs/remotes/origin/master
          .from('user_yield_distributions')
          .select('id, net_yield, gross_yield, balance_before, yield_id, vehicle_id, yields!inner(yield_type, yield_amount, applied_date, created_at)')
          .eq('user_uid', userId);
      
      if (vehicleId != null) {
<<<<<<< HEAD
        yieldQuery = yieldQuery.eq('vehicle_id', vehicleId);
      }
      
      final yieldDistributions = await yieldQuery;
=======
        yieldDistributionsQuery = yieldDistributionsQuery.eq('vehicle_id', vehicleId);
      }
      
      final yieldDistributions = await yieldDistributionsQuery;
>>>>>>> refs/remotes/origin/master
      
      for (var yieldDist in yieldDistributions) {
        final netYield = (yieldDist['net_yield'] as num).toDouble();
        final grossYield = (yieldDist['gross_yield'] as num).toDouble();
        final balanceBefore = (yieldDist['balance_before'] as num).toDouble();
        final yieldsData = yieldDist['yields'] as Map<String, dynamic>;
        final appliedDate = DateTime.parse(yieldsData['applied_date'] as String);
        final createdAtStr = yieldsData['created_at'] as String?;
        
        DateTime actionDate;
        if (createdAtStr != null && createdAtStr.isNotEmpty) {
          try {
            actionDate = DateTime.parse(createdAtStr);
          } catch (e) {
            actionDate = appliedDate;
          }
        } else {
          actionDate = appliedDate;
        }
        
        double yieldPercent = 0.0;
        if (balanceBefore > 0) {
          yieldPercent = (grossYield / balanceBefore) * 100;
        }
        
        allTransactions.add(TransactionHistoryItem(
          id: yieldDist['id'] as int,
          type: 'Yield',
          amount: netYield,
          yieldPercent: yieldPercent,
          status: 'Applied',
          date: appliedDate,
          actionDate: actionDate,
          isPositive: netYield >= 0,
        ));
      }
      
      // Sort by actionDate (most recent first) - will be re-sorted by filter
      allTransactions.sort((a, b) => b.actionDate.compareTo(a.actionDate));
      
      if (mounted) {
        setState(() {
          _userTransactions = allTransactions;
          _applyUserFilter();
          _isLoadingTransactions = false;
        });
      }
    } catch (e) {
      print('[AdminScreen] Error loading user transactions: $e');
      if (mounted) {
        setState(() {
          _isLoadingTransactions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transaction history: $e')),
        );
      }
    }
  }

  Future<void> _showEditProfileDialog(UserProfile user) async {
    final firstNameController = TextEditingController(text: user.firstName ?? '');
    final lastNameController = TextEditingController(text: user.lastName ?? '');
    final emailController = TextEditingController(text: user.email);
    String? avatarUrl = user.avatarUrl;
    int avatarRefreshKey = 0;
    bool isUploadingAvatar = false;
    bool isUpdatingUser = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: Row(
                children: [
                  Icon(Icons.edit, color: AppColors.primaryColor),
                  const SizedBox(width: 12),
                  const TitleText('Edit Profile', fontSize: 20),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar section
                      Center(
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: avatarUrl != null
                                      ? NetworkImage('$avatarUrl?key=$avatarRefreshKey')
                                      : null,
                                  child: avatarUrl == null
                                      ? Icon(Icons.person, size: 60, color: Colors.grey.shade600)
                                      : null,
                                ),
                                if (isUploadingAvatar)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            StyledButton(
                              onPressed: isUploadingAvatar ? null : () async {
                                try {
                                  final ImageSource? source = await showDialog<ImageSource>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Select Image Source'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.photo_library),
                                            title: const Text('Photo Library'),
                                            onTap: () => Navigator.pop(context, ImageSource.gallery),
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.camera_alt),
                                            title: const Text('Camera'),
                                            onTap: () => Navigator.pop(context, ImageSource.camera),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  
                                  if (source == null) return;
                                  
                                  final XFile? pickedFile = await _imagePicker.pickImage(source: source);
                                  if (pickedFile == null) return;
                                  
                                  final Uint8List originalBytes = await pickedFile.readAsBytes();
                                  final img.Image? originalImage = img.decodeImage(originalBytes);
                                  if (originalImage == null) {
                                    throw Exception('Failed to decode image');
                                  }
                                  
                                  final int size = originalImage.width < originalImage.height 
                                      ? originalImage.width 
                                      : originalImage.height;
                                  final int x = (originalImage.width - size) ~/ 2;
                                  final int y = (originalImage.height - size) ~/ 2;
                                  
                                  final img.Image croppedImage = img.copyCrop(
                                    originalImage,
                                    x: x,
                                    y: y,
                                    width: size,
                                    height: size,
                                  );
                                  
                                  final int targetSize = size > 800 ? 800 : size;
                                  final img.Image resizedImage = img.copyResize(
                                    croppedImage,
                                    width: targetSize,
                                    height: targetSize,
                                    interpolation: img.Interpolation.cubic,
                                  );
                                  
                                  final Uint8List pngBytes = Uint8List.fromList(img.encodePng(resizedImage));
                                  final Directory tempDir = Directory.systemTemp;
                                  final String tempPath = '${tempDir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png';
                                  final File imageFile = File(tempPath);
                                  await imageFile.writeAsBytes(pngBytes);
                                  
                                  setDialogState(() => isUploadingAvatar = true);
                                  
                                  final newAvatarUrl = await _avatarService.uploadAvatar(imageFile, user.uid);
                                  await _avatarService.updateProfileAvatarUrl(user.uid, newAvatarUrl);
                                  
                                  try {
                                    if (await imageFile.exists()) await imageFile.delete();
                                  } catch (e) {
                                    print('[EditProfileDialog] Warning: Could not delete temp file: $e');
                                  }
                                  
                                  setDialogState(() {
                                    isUploadingAvatar = false;
                                    avatarUrl = newAvatarUrl;
                                    avatarRefreshKey++;
                                  });
                                  
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Avatar updated successfully!')),
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(() => isUploadingAvatar = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error uploading avatar: $e')),
                                    );
                                  }
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  PrimaryTextW('Change Profile Picture'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Form fields
                      const SecondaryText('First Name', fontSize: 14),
                      const SizedBox(height: 8),
                      StyledTextfield(
                        controller: firstNameController,
                        keyboardType: TextInputType.text,
                        label: 'Enter first name',
                      ),
                      const SizedBox(height: 16),
                      
                      const SecondaryText('Last Name', fontSize: 14),
                      const SizedBox(height: 8),
                      StyledTextfield(
                        controller: lastNameController,
                        keyboardType: TextInputType.text,
                        label: 'Enter last name',
                      ),
                      const SizedBox(height: 16),
                      
                      const SecondaryText('Email', fontSize: 14),
                      const SizedBox(height: 8),
                      StyledTextfield(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        label: 'Enter email',
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                StyledButton(
                  onPressed: isUpdatingUser ? null : () async {
                    setDialogState(() => isUpdatingUser = true);
                    try {
                      await _updateUserProfile(
                        user,
                        firstNameController.text.trim(),
                        lastNameController.text.trim(),
                        emailController.text.trim(),
                      );
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    } finally {
                      setDialogState(() => isUpdatingUser = false);
                    }
                  },
                  child: isUpdatingUser
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : PrimaryTextW('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    // Dispose controllers after dialog closes
    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        firstNameController.dispose();
        lastNameController.dispose();
        emailController.dispose();
      } catch (e) {
        print('[EditProfileDialog] Controller disposal: $e');
      }
    });
  }


  Future<void> _updateUserProfile(UserProfile user, String firstName, String lastName, String email) async {
    if (firstName.trim().isEmpty ||
        lastName.trim().isEmpty ||
        email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('profiles')
          .update({
            'first_name': firstName.trim(),
            'last_name': lastName.trim(),
            'email': email.trim(),
          })
          .eq('id', user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload users to get updated data
        await _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  void _applyUserFilter() {
    List<TransactionHistoryItem> filtered = List.from(_userTransactions);

    // Apply type filter
    switch (_selectedUserType) {
      case UserTransactionType.yields:
        filtered = filtered.where((trans) => trans.type == 'Yield').toList();
        break;
      case UserTransactionType.transactions:
        filtered = filtered.where((trans) => trans.type == 'Deposit' || trans.type == 'Withdrawal').toList();
        break;
      case UserTransactionType.pending:
        filtered = filtered.where((trans) => trans.status == 'Verifying' || trans.status == 'PENDING').toList();
        break;
      case UserTransactionType.all:
        // Show all transactions
        break;
    }

    // Apply date sorting
    switch (_currentUserFilter) {
      case TransactionFilter.dateAscending:
        filtered.sort((a, b) => a.date.compareTo(b.date)); // Ascending
        break;
      case TransactionFilter.dateDescending:
        filtered.sort((a, b) => b.date.compareTo(a.date)); // Descending
        break;
    }

    setState(() {
      _filteredUserTransactions = filtered;
    });
  }

  Widget _buildUserTypeToggle(String label, UserTransactionType type) {
    final isSelected = _selectedUserType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            // If already selected, toggle it off (reset to all)
            if (isSelected) {
              _selectedUserType = UserTransactionType.all;
            } else {
              _selectedUserType = type;
            }
          });
          _applyUserFilter();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryColor : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleUserStatus(UserProfile user) async {
    setState(() => _isTogglingUserStatus = true);

    try {
      final supabase = Supabase.instance.client;
      final newStatus = !user.isActive;
      
      await supabase
          .from('profiles')
          .update({'is_active': newStatus})
          .eq('id', user.uid);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'User enabled successfully!' : 'User disabled successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload users to get updated data
        await _loadUsers();
        
        // Update selected user if it's the same user
        if (_selectedUser?.uid == user.uid) {
          final updatedUser = _allUsers.firstWhere(
            (u) => u.uid == user.uid,
            orElse: () => user,
          );
          _onUserSelected(updatedUser);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling user status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingUserStatus = false);
      }
    }
  }

  Widget _buildManageUsersView() {
    return RefreshIndicator(
      onRefresh: _refreshManageUsersView,
      color: AppColors.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TitleText('Manage Users', fontSize: 24, color: AppColors.titleColor),
          const SizedBox(height: 24),
          
          // User selector dropdown
          DropdownButtonFormField<UserProfile>(
            value: _selectedUser != null && _allUsers.any((u) => u.uid == _selectedUser!.uid)
                ? _allUsers.firstWhere((u) => u.uid == _selectedUser!.uid)
                : null,
            decoration: InputDecoration(
              labelText: 'Select User',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            items: _allUsers.map((user) {
              final isDisabled = user.isActive == false;
              return DropdownMenuItem<UserProfile>(
                value: user,
                child: Text(
                  '${user.firstName ?? ''} ${user.lastName ?? ''} (${user.email})',
                  style: TextStyle(
                    color: isDisabled ? Colors.red : null,
                    fontWeight: isDisabled ? FontWeight.w500 : null,
                  ),
                ),
              );
            }).toList(),
            onChanged: _isLoadingUsers ? null : _onUserSelected,
          ),
          
          if (_isLoadingUsers)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_selectedUser != null) ...[
            const SizedBox(height: 24),
            
            // Apply Personal Yield button
            StyledButton(
              backgroundColor: Colors.orange,
              onPressed: () => _showPersonalYieldDialog(_selectedUser!),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.percent_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  PrimaryTextW('Apply Personal Yield', fontSize: 14),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Action buttons - smaller and side by side
            Row(
              children: [
                Expanded(
                  child: StyledButton(
                    onPressed: () => _showEditProfileDialog(_selectedUser!),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        PrimaryTextW('Edit', fontSize: 14),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StyledButton(
                    backgroundColor: _selectedUser!.isActive ? Colors.red : Colors.green,
                    onPressed: _isTogglingUserStatus ? null : () => _toggleUserStatus(_selectedUser!),
                    child: _isTogglingUserStatus
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectedUser!.isActive ? Icons.block : Icons.check_circle,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              PrimaryTextW(
                                _selectedUser!.isActive ? 'Disable' : 'Enable',
                                fontSize: 14,
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
<<<<<<< HEAD
            // Vehicle selector (only show if user is selected and has vehicles)
            if (_selectedUser != null && 
                _userVehicles.isNotEmpty && 
                _selectedUserVehicle != null &&
                _userVehicles.length > 0) ...[
              const SecondaryText('Select Vehicle', fontSize: 14),
              const SizedBox(height: 8),
              DropdownButtonFormField<InvestmentVehicle>(
                value: () {
                  if (_userVehicles.isEmpty) return null;
                  if (_selectedUserVehicle == null) return _userVehicles.first;
                  // Find the vehicle from the list by ID to ensure same object reference
                  try {
                    return _userVehicles.firstWhere((v) => v.id == _selectedUserVehicle!.id);
                  } catch (e) {
                    // If not found, return first vehicle
                    return _userVehicles.first;
                  }
                }(),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: _userVehicles.map((vehicle) {
                  return DropdownMenuItem<InvestmentVehicle>(
                    value: vehicle,
                    child: Text(vehicle.vehicleName),
                  );
                }).toList(),
                onChanged: (vehicle) async {
                  if (vehicle != null && _selectedUser != null) {
                    // Ensure we use the vehicle from the list (same object reference)
                    final vehicleFromList = _userVehicles.firstWhere(
                      (v) => v.id == vehicle.id,
                      orElse: () => vehicle,
                    );
                    setState(() {
                      _selectedUserVehicle = vehicleFromList;
                    });
                    await _loadUserSubscriptionData(_selectedUser!.uid, vehicleFromList.id);
                    await _loadUserTransactions(_selectedUser!.uid, vehicleFromList.id);
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
            
            // HomeCard - Account Summary
            if (_selectedUserSubscription != null && !_isLoadingUserSubscription) ...[
              HomeCard(
                totalContributions: _selectedUserSubscription!.totalContributions,
                yield: _selectedUserSubscription!.yieldPercentage,
                currentBalance: _selectedUserSubscription!.currentBalance,
                totalYield: _selectedUserSubscription!.totalYield,
              ),
              const SizedBox(height: 24),
            ] else if (_isLoadingUserSubscription) ...[
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              const SizedBox(height: 24),
            ],
            
            // Transaction History Section
=======
            // User Stats Section - using HomeCard layout (same as vehicle panel)
            if (_isLoadingUserStats)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              HomeCard(
                currentBalance: _userCurrentBalance,
                yield: _userTotalContributions > 0 
                    ? ((_userCurrentBalance - _userTotalContributions) / _userTotalContributions) * 100 
                    : 0.0,
                totalContributions: _userTotalContributions,
                totalYield: _userTotalYield,
              ),
            
            // Transaction History Section with Vehicle Selector
>>>>>>> refs/remotes/origin/master
            Row(
              children: [
                Expanded(
                  child: TitleText('Transaction History', fontSize: 20, color: AppColors.titleColor),
                ),
                const SizedBox(width: 12),
                // Vehicle selector dropdown
                if (!_isLoadingVehicles && _allVehicles.isNotEmpty)
                  Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonFormField<InvestmentVehicle>(
                      value: _selectedVehicle,
                      decoration: InputDecoration(
                        hintText: 'All Vehicles',
                        hintStyle: TextStyle(
                          color: AppColors.titleColor.withOpacity(0.5),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      isExpanded: true,
                      items: [
                        // "All Vehicles" option
                        const DropdownMenuItem<InvestmentVehicle>(
                          value: null,
                          child: Text('All Vehicles', style: TextStyle(fontSize: 14)),
                        ),
                        // Vehicle options
                        ..._allVehicles.map((vehicle) {
                          return DropdownMenuItem<InvestmentVehicle>(
                            value: vehicle,
                            child: Text(
                              vehicle.vehicleName,
                              style: const TextStyle(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: _isLoadingTransactions ? null : _onVehicleSelected,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Filter tabs and date filter
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildUserTypeToggle('Yields', UserTransactionType.yields),
                      const SizedBox(width: 8),
                      _buildUserTypeToggle('Transactions', UserTransactionType.transactions),
                      const SizedBox(width: 8),
                      _buildUserTypeToggle('Pending', UserTransactionType.pending),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Date filter button
                PopupMenuButton<TransactionFilter>(
                  color: Colors.white,
                  icon: Icon(Icons.filter_list_rounded),
                  onSelected: (TransactionFilter filter) {
                    setState(() {
                      _currentUserFilter = filter;
                    });
                    _applyUserFilter();
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<TransactionFilter>(
                      value: TransactionFilter.dateAscending,
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_upward,
                            size: 20,
                            color: _currentUserFilter == TransactionFilter.dateAscending
                                ? AppColors.primaryColor
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Date: Ascending',
                            style: TextStyle(
                              color: _currentUserFilter == TransactionFilter.dateAscending
                                  ? AppColors.primaryColor
                                  : Colors.grey.shade800,
                              fontWeight: _currentUserFilter == TransactionFilter.dateAscending
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (_currentUserFilter == TransactionFilter.dateAscending)
                            const Spacer(),
                          if (_currentUserFilter == TransactionFilter.dateAscending)
                            Icon(
                              Icons.check,
                              color: AppColors.primaryColor,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                    PopupMenuItem<TransactionFilter>(
                      value: TransactionFilter.dateDescending,
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_downward,
                            size: 20,
                            color: _currentUserFilter == TransactionFilter.dateDescending
                                ? AppColors.primaryColor
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Date: Descending',
                            style: TextStyle(
                              color: _currentUserFilter == TransactionFilter.dateDescending
                                  ? AppColors.primaryColor
                                  : Colors.grey.shade800,
                              fontWeight: _currentUserFilter == TransactionFilter.dateDescending
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (_currentUserFilter == TransactionFilter.dateDescending)
                            const Spacer(),
                          if (_currentUserFilter == TransactionFilter.dateDescending)
                            Icon(
                              Icons.check,
                              color: AppColors.primaryColor,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_isLoadingTransactions)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredUserTransactions.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: SecondaryText(
                    'No transactions found',
                    fontSize: 14,
                    color: AppColors.secondaryTextColor,
                  ),
                ),
              )
            else
              ..._filteredUserTransactions.map((transaction) {
                return TransactionCard(
                  date: TransactionHistoryService.formatDate(transaction.date),
                  amount: transaction.amount,
                  info: transaction.yieldPercent,
                  status: transaction.status,
                  type: transaction.type,
                  isPositive: transaction.isPositive,
                );
              }).toList(),
          ],
        ],
      ),
    ),
    );
  }

  Future<void> _refreshManageUsersView() async {
    // Reload users list
    await _loadUsers();
    
    // If a user is selected, reload their data
    if (_selectedUser != null) {
      final userId = _selectedUser!.uid;
      final previousVehicleId = _selectedUserVehicle?.id;
      
      // Reload vehicles for the user
      try {
        final vehicles = await YieldService.getUserVehicles(userId);
        if (mounted && vehicles.isNotEmpty) {
          InvestmentVehicle? vehicleToSelect;
          
          // Try to keep the same vehicle selected if it still exists
          if (previousVehicleId != null) {
            vehicleToSelect = vehicles.firstWhere(
              (v) => v.id == previousVehicleId,
              orElse: () => vehicles.first,
            );
          } else {
            vehicleToSelect = vehicles.first;
          }
          
          setState(() {
            _userVehicles = vehicles;
            _selectedUserVehicle = vehicleToSelect;
          });
          
          // Reload subscription data and transactions for selected vehicle
          await _loadUserSubscriptionData(userId, vehicleToSelect.id);
          await _loadUserTransactions(userId, vehicleToSelect.id);
        } else if (mounted) {
          setState(() {
            _userVehicles = [];
            _selectedUserVehicle = null;
            _selectedUserSubscription = null;
          });
        }
      } catch (e) {
        print('[AdminScreen] Error refreshing user vehicles: $e');
        if (mounted) {
          setState(() {
            _userVehicles = [];
            _selectedUserVehicle = null;
            _selectedUserSubscription = null;
          });
        }
      }
    }
  }
}
