import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';

class HomeCard extends StatelessWidget {
  const HomeCard({
    required this.currentBalance,
    required this.yield,
    required this.totalContributions,
    required this.totalYield, 
    super.key
    });

    final double currentBalance;
    final double yield;
    final double totalContributions;
    final double totalYield;


  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.decimalPattern();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      color: Color.fromRGBO(252, 252, 252, 1),
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryText('Current Balance', fontSize: 18, color: AppColors.secondaryTextColor),
                    Container(
                      // color: Colors.green,
                      width: 210,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TitleText('₱', color: Colors.grey),
                          TitleText(currencyFormatter.format(currentBalance))
                        ],
                      ),
                    )
                  ],
                ),

                Expanded(child: SizedBox(),),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryText('Yield%', fontSize: 18, color: AppColors.secondaryTextColor),
                    Container(
                      // color: Colors.green,
                      width: 120,
                      child: Row(
                        children: [
                          PrimaryText(yield.toString(), fontSize: 26, color: AppColors.increaseColor),
                          const SizedBox(width: 5,),
                          SvgPicture.asset(
                            'assets/img/icons/increase.svg',
                            width: 25,
                            )
                        ],
                      )
                    )
                  ],
                )


              ],
            ),

            const SizedBox(height: 20,),

            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryText('Total Contributions', fontSize: 18, color: AppColors.secondaryTextColor),
                    Container(
                      // color: Colors.green, 
                      // width: 180,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TitleText('₱', color: Colors.grey, fontSize: 25,),
                          TitleText(currencyFormatter.format(totalContributions), fontSize: 25,)
                        ],
                      ),
                    )
                  ],
                ),

                // Expanded(child: SizedBox(),),
                const SizedBox(width: 40,),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PrimaryText('Total Yield', fontSize: 18, color: AppColors.secondaryTextColor),
                    Container(
                      // color: Colors.green,
                      width: 140,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TitleText('₱', color: Colors.grey, fontSize: 25,),
                          TitleText(currencyFormatter.format(totalYield), fontSize: 25,)
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),

          ],
        ),
      )
    );
  }
}

class AFFCard extends StatelessWidget {
  const AFFCard ({
    required this.title,
    required this.yield,
    required this.date,
    required this.onTap,
    required this.color,
    super.key
    });

    final String title;
    final double yield;
    final String date;
    final void Function() onTap;
    final dynamic color;


  @override
  Widget build(BuildContext context) {

    final ShapeBorder shape =
        Theme.of(context).cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      color: color,
      shadowColor: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // borderRadius: BorderRadius.all(Radius.circular(16)),
        highlightColor: Colors.grey.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TitleText(title, color: Colors.white, fontSize: 25,),
                      Row(
                        children: [
                          TitleText('+${yield}%', fontSize: 18, color: Colors.white), // ask about yield data on db
                          const SizedBox(width: 7,),
                          PrimaryTextW('Last updated: ${date}', fontSize: 13,)
                        ],
                      )
                    ],
                  ),
        
                  Expanded(child: SizedBox(),),
        
                  SvgPicture.asset(
                    'assets/img/icons/white_arrow_circle.svg',
                    width: 36,
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class DiscoverCard extends StatelessWidget {
  const DiscoverCard ({
    required this.title,
    required this.onTap,
    required this.color,
    super.key
    });

    final void Function() onTap;
    final dynamic color;
    final String title;


  @override
  Widget build(BuildContext context) {

    final ShapeBorder shape =
        Theme.of(context).cardTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      color: color,
      shadowColor: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // borderRadius: BorderRadius.all(Radius.circular(16)),
        highlightColor: Colors.grey.withOpacity(0.5),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TitleText(title, fontSize: 20,),
                    ],
                  ),
        
                  Expanded(child: SizedBox(),),
        
                  SvgPicture.asset(
                    'assets/img/icons/orange_arrow_circle.svg',
                    width: 36,
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}


class TransactionCard extends StatelessWidget {
  const TransactionCard ({
    super.key,
    required this.date,
    required this.amount,
    this.info,
    required this.status,
    });

    final String date;
    final double amount;
    final double? info;
    final String status;

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.decimalPattern();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      color: Color.fromRGBO(248, 248, 248, 1),
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              // mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TitleText('+ ₱' + currencyFormatter.format(amount), color: AppColors.titleColor, fontSize: 18,),
                    PrimaryText(date, color: AppColors.secondaryTextColor, fontSize: 15,)
                  ],
                ),

                Expanded(child: SizedBox(),),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    PrimaryText('+${info.toString()}%', color: AppColors.increaseColor, fontSize: 18,),
                    
                    PrimaryText(status, color: AppColors.secondaryTextColor, fontSize: 15,),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}