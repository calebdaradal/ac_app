import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/styled_card.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

class AscScreen extends StatefulWidget {
  static const routeName = '/ascscreen';
  const AscScreen({super.key});

  @override
  State<AscScreen> createState() => _AscScreenState();
}

class _AscScreenState extends State<AscScreen> {
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
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        
        appBar: AppBar(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          // systemOverlayStyle: SystemUiOverlayStyle.light, // iOS: white status bar content on orange
        ),
        body: SingleChildScrollView(
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
                    TitleText('Ascendo Futures Funds', color: Colors.white),
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
                        currentBalance: 0,
                        yield: 0,
                        totalContributions: 0,
                        totalYield: 0,
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
                              'assets/img/icons/arrow_down_bg.svg',
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        PrimaryText('Recent Transactions', fontSize: 14, color: Colors.grey),
                        GestureDetector(
                          onTap: _showTransactionsSheet,
                          child: PrimaryText('See All', color: AppColors.primaryColor),
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
      ),
    );
  }
}