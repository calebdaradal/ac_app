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
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PrimaryText('Current Balance', fontSize: 18, color: AppColors.secondaryTextColor),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TitleText('₱', color: Colors.grey),
                          Flexible(
                            child: TitleText(
                              currencyFormatter.format(currentBalance),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PrimaryText('Yield%', fontSize: 18, color: AppColors.secondaryTextColor),
                      Row(
                        children: [
                          Flexible(
                            child: PrimaryText(
                              yield.toStringAsFixed(2),
                              fontSize: 26,
                              color: AppColors.increaseColor,
                            ),
                          ),
                          const SizedBox(width: 5),
                          SvgPicture.asset(
                            'assets/img/icons/increase.svg',
                            width: 25,
                          )
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),

            const SizedBox(height: 20,),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PrimaryText('Total Contributions', fontSize: 18, color: AppColors.secondaryTextColor),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TitleText('₱', color: Colors.grey, fontSize: 25,),
                          Flexible(
                            child: TitleText(
                              currencyFormatter.format(totalContributions),
                              fontSize: 25,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PrimaryText('Total Yield', fontSize: 18, color: AppColors.secondaryTextColor),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TitleText('₱', color: Colors.grey, fontSize: 25,),
                          Flexible(
                            child: TitleText(
                              currencyFormatter.format(totalYield),
                              fontSize: 25,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                          TitleText('+${yield.toStringAsFixed(2)}%', fontSize: 18, color: Colors.white), // ask about yield data on db
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
  const TransactionCard({
    super.key,
    required this.date,
    required this.amount,
    this.info,
    required this.status,
    this.type,
    this.isPositive = true,
  });

  final String date;
  final double amount;
  final double? info;
  final String status;
  final String? type;
  final bool isPositive; // true for deposits/yields, false for withdrawals

  @override
  Widget build(BuildContext context) {
    final NumberFormat currencyFormatter = NumberFormat.decimalPattern();
    final prefix = isPositive ? '+ ₱' : '- ₱';
    final amountColor = isPositive ? AppColors.increaseColor : AppColors.titleColor;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
      color: const Color.fromRGBO(248, 248, 248, 1),
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: TitleText(
                              '$prefix${currencyFormatter.format(amount)}',
                              color: amountColor,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      PrimaryText(
                        date,
                        color: AppColors.secondaryTextColor,
                        fontSize: 15,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (type != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getTypeColor(type!).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: PrimaryText(
                          type!,
                          color: _getTypeColor(type!),
                          fontSize: 12,
                        ),
                      ),
                    if (info != null) ...[
                      const SizedBox(height: 4),
                      PrimaryText(
                        '+${info!.toStringAsFixed(2)}%',
                        color: AppColors.increaseColor,
                        fontSize: 16,
                      ),
                    ],
                    const SizedBox(height: 4),
                    PrimaryText(
                      status,
                      color: _getStatusColor(status),
                      fontSize: 13,
                    ),
                  ],
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'deposit':
        return AppColors.increaseColor;
      case 'withdrawal':
        return Colors.orange;
      case 'yield':
        return AppColors.primaryColor;
      default:
        return AppColors.titleColor;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'verified':
      case 'completed':
      case 'applied':
        return AppColors.increaseColor;
      case 'verifying':
      case 'pending':
        return Colors.orange;
      case 'denied':
      case 'failed':
        return Colors.red;
      default:
        return AppColors.secondaryTextColor;
    }
  }
}

class BankDetailsCard extends StatelessWidget {
  const BankDetailsCard({
    required this.bankName,
    required this.accountNumber,
    required this.locationName,
    required this.accountName,
    this.onTap,
    super.key
    });

    final String bankName;
    final String accountNumber;
    final String locationName;
    final String accountName;
    final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
        color: AppColors.primaryColor.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.primaryColor.withOpacity(0.1), width: 2),
        ),
        shadowColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TitleText('Bank Name', color: AppColors.titleColor, fontSize: 18,),
                    PrimaryText(bankName, fontSize: 16, color: AppColors.secondaryTextColor,)
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TitleText('Account Number', color: AppColors.titleColor, fontSize: 18,),
                    PrimaryText(accountNumber, fontSize: 16, color: AppColors.secondaryTextColor,)
                  ],
                )
              ],
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TitleText('Location', color: AppColors.titleColor, fontSize: 18,),
                    PrimaryText(locationName, fontSize: 16, color: AppColors.secondaryTextColor,)
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TitleText('Account Name', color: AppColors.titleColor, fontSize: 18,),
                    PrimaryText(accountName, fontSize: 16, color: AppColors.secondaryTextColor,)
                  ],
                )
              ],
            )
          ],
        ),
      ),
      ),
    );
  }
}