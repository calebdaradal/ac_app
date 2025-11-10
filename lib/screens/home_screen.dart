import 'package:ac_app/shared/styled_card.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/pin_storage.dart';
import 'welcome_screen.dart';
import 'vehicles/asc_screen.dart';
import 'vehicles/stk_screen.dart';

class HomeScreen extends StatelessWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    await PinStorage.clearPin();
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        WelcomeScreen.routeName,
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 90,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        // leadingWidth: 72,
        flexibleSpace: Padding(
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
                          image: DecorationImage(
                            image: AssetImage(
                              'assets/img/sample/man.jpg',
                              ),
                            // fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TitleText('Sef Jacob', fontSize: 18, color: AppColors.titleColor),
                          PrimaryText('sample@email.com', fontSize: 14, color: AppColors.secondaryTextColor)
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
                    onTap: () {},
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                    highlightColor: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: SvgPicture.asset(
                        'assets/img/icons/notification.svg',
                        width: 29,
                        ),
                    ),
                  ),
    
                  // const SizedBox(width: 3,),
    
                  InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.all(Radius.circular(25)),
                    highlightColor: Colors.grey.withOpacity(0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: SvgPicture.asset(
                        'assets/img/icons/settings.svg',
                        width: 29,
                        ),
                    ),
                  ),
                ],
              )
            ],
          ),
    
        ),
        ),
      body: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          // mainAxisSize: MainAxisSize.min,
          
          children: [
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TitleText('Account Summary', color: Colors.grey, fontSize: 19,),
    
                HomeCard(
                  totalContributions:2980000.00,
                  yield: 31.13,
                  currentBalance: 3369221.68,
                  totalYield: 389221.68,
                ),
                
                AFFCard(
                  title: 'Ascendo Futures Fund',
                  yield: 23.35,
                  date: '10/12/2025',
                  onTap: () {
                    Navigator.pushNamed(context, AscScreen.routeName);
                  },
                  color: AppColors.primaryColor,
                ),
    
                AFFCard(
                  title: 'SOL/ETH Staking Pool',
                  yield: 7.78,
                  date: '10/12/2025',
                  onTap: () {
                    Navigator.pushNamed(context, StkScreen.routeName);
                  },
                  color: AppColors.tertiaryColor
                ),
    
                DiscoverCard(
                  color: AppColors.secondaryColor,
                  title: 'Discover more opportunities',
                  onTap: () {}
                )
              ],
            ),
            
            const SizedBox(height: 16),
              
              
              
            // ElevatedButton(
            //   onPressed: () => _signOut(context),
            //   child: const Text('Sign out'),
            // ),
          ],
        ),
      ),
    );
  }
}


