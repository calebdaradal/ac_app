import 'package:ac_app/screens/vehicles/deposit_screen.dart';
import 'package:ac_app/screens/vehicles/withdraw_screen.dart';
import 'package:ac_app/services/investment_service.dart';
import 'package:ac_app/services/transaction_history_service.dart';
import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/styled_card.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

const _pageIdentifier = 'SP';

enum TransactionFilter {
  removeFilters, // Reset to default
  dateAscending,
  dateDescending,
  yield,
  transactions,
  allPending,
}

class StkScreen extends StatefulWidget {
  static const routeName = '/stkscreen';
  const StkScreen({super.key});

  @override
  State<StkScreen> createState() => _StkScreenState();
}

class _StkScreenState extends State<StkScreen> {
  UserVehicleSubscription? _subscription;
  bool _loading = true;
  List<TransactionHistoryItem> _recentTransactions = [];
  List<TransactionHistoryItem> _allTransactions = []; // Keep all transactions for filtering
  List<TransactionHistoryItem> _filteredTransactions = []; // Filtered list shown to user
  TransactionFilter _currentFilter = TransactionFilter.dateDescending; // Default filter
  bool _loadingTransactions = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
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
          if (_allTransactions.isNotEmpty) {
            _applyFilter();
          } else {
            _filteredTransactions = [];
            _recentTransactions = [];
          }
          _loadingTransactions = false;
        });
      }
    } catch (e) {
      print('[StkScreen] Error loading transactions: $e');
      if (mounted) {
        setState(() => _loadingTransactions = false);
      }
    }
  }

  void _applyFilter() {
    List<TransactionHistoryItem> filtered = List.from(_allTransactions);

    switch (_currentFilter) {
      case TransactionFilter.removeFilters:
        // Reset to default filter (Date: Descending)
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        filtered = filtered.where((trans) {
          final appliedDate = trans.date;
          final appliedDateOnly = DateTime(appliedDate.year, appliedDate.month, appliedDate.day);
          return appliedDateOnly.isBefore(today) || appliedDateOnly.isAtSameMomentAs(today);
        }).toList();
        filtered.sort((a, b) => b.date.compareTo(a.date)); // Descending
        break;

      case TransactionFilter.dateAscending:
        // Filter by applied_at date (only applied transactions) and sort ascending
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        filtered = filtered.where((trans) {
          final appliedDate = trans.date;
          final appliedDateOnly = DateTime(appliedDate.year, appliedDate.month, appliedDate.day);
          return appliedDateOnly.isBefore(today) || appliedDateOnly.isAtSameMomentAs(today);
        }).toList();
        filtered.sort((a, b) => a.date.compareTo(b.date)); // Ascending
        break;

      case TransactionFilter.dateDescending:
        // Filter by applied_at date (only applied transactions) and sort descending
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        filtered = filtered.where((trans) {
          final appliedDate = trans.date;
          final appliedDateOnly = DateTime(appliedDate.year, appliedDate.month, appliedDate.day);
          return appliedDateOnly.isBefore(today) || appliedDateOnly.isAtSameMomentAs(today);
        }).toList();
        filtered.sort((a, b) => b.date.compareTo(a.date)); // Descending
        break;

      case TransactionFilter.yield:
        // Show only Yield transactions
        filtered = filtered.where((trans) => trans.type == 'Yield').toList();
        filtered.sort((a, b) => b.date.compareTo(a.date)); // Most recent first
        break;

      case TransactionFilter.transactions:
        // Show only Deposits and Withdrawals (exclude Yields)
        filtered = filtered.where((trans) => trans.type == 'Deposit' || trans.type == 'Withdrawal').toList();
        filtered.sort((a, b) => b.date.compareTo(a.date)); // Most recent first
        break;

      case TransactionFilter.allPending:
        // Show only pending/verifying transactions
        filtered = filtered.where((trans) => trans.status == 'Verifying' || trans.status == 'PENDING').toList();
        filtered.sort((a, b) => b.date.compareTo(a.date)); // Most recent first
        break;
    }

    setState(() {
      _filteredTransactions = filtered;
      _recentTransactions = _filteredTransactions.isNotEmpty 
          ? _filteredTransactions.take(3).toList()
          : [];
    });
  }

  Future<void> _refreshData() async {
    await _loadSubscriptionData();
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
      _loadTransactionHistory();
    }
  }

  Future<void> _navigateToWithdraw() async {
    if (_subscription == null) {
      await _showWarningDialog('Unable to load vehicle information');
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
      arguments: _subscription!.vehicleId,  // Only pass the ID
    );

    // Refresh data if withdrawal was made
    if (result == true) {
      _loadSubscriptionData();
      _loadTransactionHistory();
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
      useSafeArea: true, // keep above status bar/notch
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
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(height: 12),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Text(
                                'All Transactions',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: PopupMenuButton<TransactionFilter>(
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
                                  value: TransactionFilter.removeFilters,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.clear_all,
                                        size: 20,
                                        color: _currentFilter == TransactionFilter.removeFilters
                                            ? AppColors.tertiaryColor
                                            : Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Remove Filters',
                                        style: TextStyle(
                                          color: _currentFilter == TransactionFilter.removeFilters
                                              ? AppColors.tertiaryColor
                                              : Colors.grey.shade800,
                                          fontWeight: _currentFilter == TransactionFilter.removeFilters
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (_currentFilter == TransactionFilter.removeFilters)
                                        const Spacer(),
                                      if (_currentFilter == TransactionFilter.removeFilters)
                                        Icon(
                                          Icons.check,
                                          color: AppColors.tertiaryColor,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem<TransactionFilter>(
                                  value: TransactionFilter.dateAscending,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_upward,
                                        size: 20,
                                        color: _currentFilter == TransactionFilter.dateAscending
                                            ? AppColors.tertiaryColor
                                            : Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Date: Ascending',
                                        style: TextStyle(
                                          color: _currentFilter == TransactionFilter.dateAscending
                                              ? AppColors.tertiaryColor
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
                                          color: AppColors.tertiaryColor,
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
                                            ? AppColors.tertiaryColor
                                            : Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Date: Descending',
                                        style: TextStyle(
                                          color: _currentFilter == TransactionFilter.dateDescending
                                              ? AppColors.tertiaryColor
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
                                          color: AppColors.tertiaryColor,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<TransactionFilter>(
                                  value: TransactionFilter.yield,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.trending_up,
                                        size: 20,
                                        color: _currentFilter == TransactionFilter.yield
                                            ? AppColors.tertiaryColor
                                            : Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Yield',
                                        style: TextStyle(
                                          color: _currentFilter == TransactionFilter.yield
                                              ? AppColors.tertiaryColor
                                              : Colors.grey.shade800,
                                          fontWeight: _currentFilter == TransactionFilter.yield
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (_currentFilter == TransactionFilter.yield)
                                        const Spacer(),
                                      if (_currentFilter == TransactionFilter.yield)
                                        Icon(
                                          Icons.check,
                                          color: AppColors.tertiaryColor,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<TransactionFilter>(
                                  value: TransactionFilter.transactions,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.swap_horiz,
                                        size: 20,
                                        color: _currentFilter == TransactionFilter.transactions
                                            ? AppColors.tertiaryColor
                                            : Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Transactions',
                                        style: TextStyle(
                                          color: _currentFilter == TransactionFilter.transactions
                                              ? AppColors.tertiaryColor
                                              : Colors.grey.shade800,
                                          fontWeight: _currentFilter == TransactionFilter.transactions
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (_currentFilter == TransactionFilter.transactions)
                                        const Spacer(),
                                      if (_currentFilter == TransactionFilter.transactions)
                                        Icon(
                                          Icons.check,
                                          color: AppColors.tertiaryColor,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem<TransactionFilter>(
                                  value: TransactionFilter.allPending,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.pending,
                                        size: 20,
                                        color: _currentFilter == TransactionFilter.allPending
                                            ? AppColors.tertiaryColor
                                            : Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'All Pending',
                                        style: TextStyle(
                                          color: _currentFilter == TransactionFilter.allPending
                                              ? AppColors.tertiaryColor
                                              : Colors.grey.shade800,
                                          fontWeight: _currentFilter == TransactionFilter.allPending
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (_currentFilter == TransactionFilter.allPending)
                                        const Spacer(),
                                      if (_currentFilter == TransactionFilter.allPending)
                                        Icon(
                                          Icons.check,
                                          color: AppColors.tertiaryColor,
                                          size: 20,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: (_filteredTransactions.isEmpty || _filteredTransactions.length == 0 || _allTransactions.isEmpty)
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
                                if (i >= _filteredTransactions.length) return const SizedBox.shrink();
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
        backgroundColor: AppColors.tertiaryColor,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: AppColors.tertiaryColor,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leadingWidth: 56,
        titleSpacing: 0,
        // actions: [
        //   Padding(
        //     padding: const EdgeInsets.only(right: 16.0),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.tertiaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              color: AppColors.tertiaryColor,
              height: 110,
              padding: const EdgeInsets.only(bottom: 15.0, left: 15, right: 15),
              child: Row(
                children: [
                  TitleText('SOL/ETH Staking Pool', color: Colors.white),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    
            // Card with bottom-centered button (overlap preserved)
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    HomeCard(
                      currentBalance: _subscription?.currentBalance ?? 0.0,
                      yield: _subscription?.yieldPercentage ?? 0.0,
                      totalContributions: _subscription?.totalContributions ?? 0.0,
                      totalYield: _subscription?.calculatedYield ?? 0.0,
                    ),
                    Positioned(
                      bottom: -30,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            // TODO: expand/collapse recent transactions
                          },
                          child: SvgPicture.asset(
                            'assets/img/icons/stk_arrow_down.svg',
                            width: 80,
                            height: 80,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                          backgroundColor: AppColors.tertiaryColor,
                          onPressed: _navigateToDeposit, 
                          child: TitleText('Deposit Funds', color: Colors.white, fontSize: 16),
                        ),
                      ),

                      // Expanded(child: SizedBox(width: 10,)),
                      const SizedBox(width: 6),
                      
                      Expanded(
                        child: StyledButton(
                          backgroundColor: const Color.fromARGB(255, 85, 85, 85),
                          onPressed: _navigateToWithdraw, 
                          child: TitleText('Withdraw Funds', color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      PrimaryText('Recent Transactions', fontSize: 14, color: Colors.grey),
                      GestureDetector(
                        onTap: _showTransactionsSheet,
                        child: PrimaryText('See All', color: AppColors.tertiaryColor),
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
    );
  }
}