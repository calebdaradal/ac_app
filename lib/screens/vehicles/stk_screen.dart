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
  List<TransactionHistoryItem> _allTransactions = [];
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
          _recentTransactions = transactions.take(3).toList(); // Show last 3
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load vehicle information')),
      );
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
  void _showTransactionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // keep above status bar/notch
      backgroundColor: Colors.transparent,
      builder: (context) {
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
                    const Text('All Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _allTransactions.isEmpty
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
                              itemCount: _allTransactions.length,
                              itemBuilder: (_, i) {
                                final trans = _allTransactions[i];
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      
      appBar: AppBar(
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
          : SingleChildScrollView(
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
                      totalYield: _subscription?.totalYield ?? 0.0,
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
    );
  }
}