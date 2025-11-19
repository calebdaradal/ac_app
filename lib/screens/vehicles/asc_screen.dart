import 'package:ac_app/screens/vehicles/deposit_screen.dart';
import 'package:ac_app/screens/vehicles/withdraw_screen.dart';
import 'package:ac_app/services/investment_service.dart';
import 'package:ac_app/services/transaction_history_service.dart';
import 'package:ac_app/services/admin_settings_service.dart';
import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/styled_card.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _pageIdentifier = 'AFF';

enum TransactionFilter {
  dateAscending,
  dateDescending,
}

enum TransactionType {
  all,
  yields,
  transactions,
  pending,
}

class AscScreen extends StatefulWidget {
  static const routeName = '/ascscreen';
  const AscScreen({super.key});

  @override
  State<AscScreen> createState() => _AscScreenState();
}

class _AscScreenState extends State<AscScreen> {
  UserVehicleSubscription? _subscription;
  bool _loading = true;
  List<TransactionHistoryItem> _recentTransactions = [];
  List<TransactionHistoryItem> _allTransactions = []; // Keep all transactions for filtering
  List<TransactionHistoryItem> _filteredTransactions = []; // Filtered list shown to user
  TransactionFilter _currentFilter = TransactionFilter.dateDescending; // Default date sort
  TransactionType _selectedType = TransactionType.all; // Default type filter
  bool _loadingTransactions = false;
  bool _isWithdrawalAllowed = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
    _checkWithdrawalAvailability();
  }

  Future<void> _checkWithdrawalAvailability() async {
    try {
      final isAllowed = await AdminSettingsService.isWithdrawalAllowed();
      if (mounted) {
        setState(() {
          _isWithdrawalAllowed = isAllowed;
        });
      }
    } catch (e) {
      print('[AscScreen] Error checking withdrawal availability: $e');
      // If there's an error, allow withdrawal by default
      if (mounted) {
        setState(() {
          _isWithdrawalAllowed = true;
        });
      }
    }
  }

  Future<void> _loadSubscriptionData() async {
    try {
      final subscription = await InvestmentService.checkSubscription(_pageIdentifier);
      if (mounted) {
        setState(() {
          _subscription = subscription;
          _loading = false;
        });
        // Load transactions after subscription is loaded
        if (subscription != null) {
          _loadTransactionHistory();
        }
      }
    } catch (e) {
      // If vehicle not found, still allow navigation but show error
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Vehicle not found. Please contact support.')),
        );
      }
    }
  }

  Future<void> _loadTransactionHistory() async {
    if (_subscription?.vehicleId == null) return;

    setState(() => _loadingTransactions = true);
    
    try {
      final transactions = await TransactionHistoryService.getVehicleTransactionHistory(
        _subscription!.vehicleId,
      );
      
      if (mounted) {
        setState(() {
          _allTransactions = transactions;
          _applyFilter();
          _loadingTransactions = false;
        });
      }
    } catch (e) {
      print('[AscScreen] Error loading transactions: $e');
      if (mounted) {
        setState(() => _loadingTransactions = false);
      }
    }
  }

  void _applyFilter() {
    List<TransactionHistoryItem> filtered = List.from(_allTransactions);

    // Apply type filter
    switch (_selectedType) {
      case TransactionType.yields:
        filtered = filtered.where((trans) => trans.type == 'Yield').toList();
        break;
      case TransactionType.transactions:
        filtered = filtered.where((trans) => trans.type == 'Deposit' || trans.type == 'Withdrawal').toList();
        break;
      case TransactionType.pending:
        filtered = filtered.where((trans) => trans.status == 'Verifying' || trans.status == 'PENDING').toList();
        break;
      case TransactionType.all:
        // Show all transactions
        break;
    }

    // Apply date sorting
    switch (_currentFilter) {
      case TransactionFilter.dateAscending:
        filtered.sort((a, b) => a.date.compareTo(b.date)); // Ascending
        break;
      case TransactionFilter.dateDescending:
        filtered.sort((a, b) => b.date.compareTo(a.date)); // Descending
        break;
    }

    setState(() {
      _filteredTransactions = filtered;
      _recentTransactions = _filteredTransactions.take(3).toList();
    });
  }

  Widget _buildTypeToggle(String label, TransactionType type, {StateSetter? setSheetState}) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
          });
          _applyFilter();
          // Rebuild the sheet content if inside bottom sheet
          if (setSheetState != null) {
            setSheetState(() {});
          }
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

  Future<void> _refreshData() async {
    await _loadSubscriptionData();
    await _checkWithdrawalAvailability();
  }

  Future<void> _navigateToDeposit() async {
    if (_subscription == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load vehicle information')),
      );
      return;
    }
    
    final result = await Navigator.pushNamed(
      context,
      DepositFunds.routeName,
      arguments: _subscription!.vehicleId,  // Only pass the ID
    );

    // Refresh data if deposit was made
    if (result == true) {
      _loadSubscriptionData();
    }
  }

  Future<void> _navigateToWithdraw() async {
    if (_subscription == null) {
      await _showWarningDialog('Unable to load vehicle information');
      return;
    }

    // Refresh withdrawal availability before navigating
    await _checkWithdrawalAvailability();
    
    // Double-check after refresh
    if (!_isWithdrawalAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Withdrawals are not available at this time. The annual withdraw date has passed.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if user is subscribed to this vehicle
    if (!_subscription!.isSubscribed) {
      await _showWarningDialog('You must have an active investment to withdraw');
      return;
    }

    // Check if user has sufficient balance
    if (_subscription!.currentBalance <= 0) {
      await _showWarningDialog('Insufficient balance for withdrawal');
      return;
    }
    
    final result = await Navigator.pushNamed(
      context,
      WithdrawFunds.routeName,
      arguments: _subscription!.vehicleId,  // Pass the vehicle ID
    );

    // Refresh data if withdrawal was submitted
    if (result == true) {
      _loadSubscriptionData();
      await _checkWithdrawalAvailability();
    }
  }

  Future<void> _showWarningDialog(String message) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color: Colors.orange.shade700,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              const TitleText(
                'Unable to Withdraw',
                fontSize: 22,
              ),
              const SizedBox(height: 12),
              
              // Message
              SecondaryText(
                message,
                fontSize: 14,
              ),
              const SizedBox(height: 32),
              
              // OK Button
              SizedBox(
                width: double.infinity,
                child: StyledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showTransactionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext sheetContext, StateSetter setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.92,
              minChildSize: 0.6,
              maxChildSize: 1.0,
              builder: (_, scrollController) {
                return SafeArea(
                  top: true,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              // Toggle buttons for transaction types
                              Expanded(
                                child: Row(
                                  children: [
                                    _buildTypeToggle('Yields', TransactionType.yields, setSheetState: setSheetState),
                                    const SizedBox(width: 8),
                                    _buildTypeToggle('Transactions', TransactionType.transactions, setSheetState: setSheetState),
                                    const SizedBox(width: 8),
                                    _buildTypeToggle('Pending', TransactionType.pending, setSheetState: setSheetState),
                                  ],
                                ),
                              ),
                              // Date filter button
                              PopupMenuButton<TransactionFilter>(
                                color: Colors.white,
                                icon: Icon(Icons.filter_list_rounded),
                                onSelected: (TransactionFilter filter) {
                                  setState(() {
                                    _currentFilter = filter;
                                  });
                                  _applyFilter();
                                  // Rebuild the sheet content
                                  setSheetState(() {});
                                },
                                itemBuilder: (BuildContext context) => [
                                  PopupMenuItem<TransactionFilter>(
                                    value: TransactionFilter.dateAscending,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.arrow_upward,
                                          size: 20,
                                          color: _currentFilter == TransactionFilter.dateAscending
                                              ? AppColors.primaryColor
                                              : Colors.grey.shade700,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Date: Ascending',
                                          style: TextStyle(
                                            color: _currentFilter == TransactionFilter.dateAscending
                                                ? AppColors.primaryColor
                                                : Colors.grey.shade800,
                                            fontWeight: _currentFilter == TransactionFilter.dateAscending
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (_currentFilter == TransactionFilter.dateAscending)
                                          const Spacer(),
                                        if (_currentFilter == TransactionFilter.dateAscending)
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
                                          color: _currentFilter == TransactionFilter.dateDescending
                                              ? AppColors.primaryColor
                                              : Colors.grey.shade700,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Date: Descending',
                                          style: TextStyle(
                                            color: _currentFilter == TransactionFilter.dateDescending
                                                ? AppColors.primaryColor
                                                : Colors.grey.shade800,
                                            fontWeight: _currentFilter == TransactionFilter.dateDescending
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (_currentFilter == TransactionFilter.dateDescending)
                                          const Spacer(),
                                        if (_currentFilter == TransactionFilter.dateDescending)
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
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _filteredTransactions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 16),
                                  PrimaryText(
                                    'No transactions yet',
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredTransactions.length,
                              itemBuilder: (_, i) {
                                final trans = _filteredTransactions[i];
                                return TransactionCard(
                                  date: trans.displayDate,
                                  amount: trans.amount,
                                  info: trans.yieldPercent,
                                  status: trans.status,
                                  type: trans.type,
                                  isPositive: trans.isPositive,
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.primaryColor,          // match app bar color
          statusBarIconBrightness: Brightness.light,       // Android: white icons
          statusBarBrightness: Brightness.dark,           // iOS: white icons
        ),
        leadingWidth: 56,  // Adjust back button area width
        titleSpacing: 0,   // Control spacing between leading and title
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 16.0),  // Add right padding
        //     child: IconButton(
        //       onPressed: _navigateToDeposit,
        //       icon: SvgPicture.asset(
        //         'assets/img/icons/add.svg',
        //         width: 30,
        //         height: 30,
        //         colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
        //       ),
        //     ),
        //   ),
        // ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                color: AppColors.primaryColor,
                height: 110,
                padding: const EdgeInsets.only(bottom: 15.0, left: 15, right: 15),
                child: Row(
                  children: [
                    TitleText('Ascendo Futures Fund', color: Colors.white),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            
              // Card with bottom-centered button (overlap preserved)
              Transform.translate(
                offset: const Offset(0, -30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: HomeCard(
                    currentBalance: _subscription?.currentBalance ?? 0.0,
                    yield: _subscription?.yieldPercentage ?? 0.0,
                    totalContributions: _subscription?.totalContributions ?? 0.0,
                    totalYield: _subscription?.calculatedYield ?? 0.0,
                  ),
                ),
              ),
            
              // Space so the button doesn't overlap the next section
              // const SizedBox(height: 6),
            
              // New section AFTER the HomeCard
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
        
                    Row(
                      children: [
                        Expanded(
                          child: StyledButton(
                            onPressed: _navigateToDeposit, 
                            child: TitleText('Deposit Funds', color: Colors.white, fontSize: 16),
                          ),
                        ),
        
                        // Expanded(child: SizedBox(width: 10,)),
                        const SizedBox(width: 6),
                        
                        Expanded(
                          child: StyledButton(
                            backgroundColor: _isWithdrawalAllowed 
                                ? const Color.fromARGB(255, 85, 85, 85)
                                : Colors.grey,
                            onPressed: _isWithdrawalAllowed ? _navigateToWithdraw : null, 
                            child: Text(
                              _isWithdrawalAllowed ? 'Withdraw Funds' : 'Withdraw not Available', 
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _isWithdrawalAllowed ? 16 : 13,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
        
                    const SizedBox(height: 12),
        
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PrimaryText('Recent Transactions', fontSize: 14, color: Colors.grey),
                        GestureDetector(
                          onTap: _showTransactionsSheet,
                          child: PrimaryText('See All', color: AppColors.primaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Transaction history
                    if (_loadingTransactions)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_recentTransactions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              PrimaryText(
                                'No transactions yet',
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _recentTransactions.map((trans) {
                          return TransactionCard(
                            date: trans.displayDate,
                            amount: trans.amount,
                            info: trans.yieldPercent,
                            status: trans.status,
                            type: trans.type,
                            isPositive: trans.isPositive,
                          );
                        }).toList(),
                      ),
            
                    
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}