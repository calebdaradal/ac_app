import 'package:ac_app/screens/vehicles/deposit_screen.dart';
import 'package:ac_app/screens/vehicles/withdraw_screen.dart';
import 'package:ac_app/services/investment_service.dart';
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
    }
  }
  void _showFullScreenDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, __) {
        return Material(
          color: Colors.white,
          child: SafeArea(
            child: Column(
              children: [
                AppBar(
                  // automaticallyImplyLeading: false,
                  backgroundColor: Colors.transparent,
                  title: const Text('All Transactions'),
                  
                ),
                const Expanded(
                  child: Center(child: Text('No transactions yet')),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
          child: child,
        );
      },
    );
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
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: 20,
                        itemBuilder: (_, i) => TransactionCard(
                            date: '10/10/2023',
                            amount: 1000.0 + i,
                            info: 100.0,
                            status: 'Yield',
                          ),
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
                  // const SizedBox(height: 12),
                  // Add your list/items here
                  SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        TransactionCard(
                          date: '10/10/2023',
                          amount: 1000.78,
                          info: 100.0,
                          status: 'Yield',
                        ),
                        TransactionCard(
                          date: '10/10/2023',
                          amount: 1000.0,
                          info: 100.0,
                          status: 'Yield',
                        ),
                        TransactionCard(
                          date: '10/10/2023',
                          amount: 1000.0,
                          info: 100.0,
                          status: 'Yield',
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
    );
  }
}