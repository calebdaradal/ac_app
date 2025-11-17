import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_email_screen.dart';
import '../services/pin_storage.dart';
import 'pin_unlock_screen.dart';

class WelcomeScreen extends StatelessWidget {
  static const routeName = '/welcome';
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            children: [
              const Spacer(), // pushes content down
              SvgPicture.asset(
                'assets/img/logo/ACW.svg',
                 width: 290, // optional: scale for responsiveness
              ),
              const Spacer(), // pushes content up from bottom
              Column(
                // mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                // crossAxisAlignment: CrossAxisAlignment.end,
                children: [

                  // Row(
                  //   mainAxisAlignment: MainAxisAlignment.start,
                  //   children: [
                  //     PrimaryTextW('Want to be a partner? '),
                  //     GestureDetector(
                  //       onTap: () =>
                  //           Navigator.pushNamed(context, AuthEmailScreen.routeName),
                  //       child: const PrimaryTextW(
                  //         'Sign up here',
                  //         decoration: TextDecoration.underline,
                  //       ),
                  //     ),
                  //   ],
                  // ),
              
                  const SizedBox(height: 20),
              
                  // Row(
                  //   // crossAxisAlignment: CrossAxisAlignment.baseline,
                  //   // textBaseline: TextBaseline.alphabetic,
                  //   mainAxisAlignment: MainAxisAlignment.start,
                  //   children: [
                  //     GestureDetector(
                  //       onTap: () {},
                  //       child: const PrimaryTextW('Learn more about our vetting process', decoration: TextDecoration.underline),
                  //     ),
                  //     const SizedBox(width: 8,),
                  //     Padding(
                  //       padding: const EdgeInsets.only(top: 3.0),
                  //       child: SvgPicture.asset(
                  //         'assets/img/icons/white_arrow.svg',
                  //         width: 16,
                  //         height: 16,
                  //         alignment: Alignment.bottomCenter,
                  //       ),
                  //     )
                  //   ],
                  // ),

                  // const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          onPressed: () async {
                            // Check only local PIN; if present, unlock with PIN, otherwise go to email auth
                            final storedPin = await PinStorage.readPin();
                            if (storedPin != null) {
                              if (context.mounted) {
                                Navigator.pushNamed(context, PinUnlockScreen.routeName);
                              }
                            } else {
                              if (context.mounted) {
                                Navigator.pushNamed(context, AuthEmailScreen.routeName);
                              }
                            }
                          },
                          child: const PrimaryText('Partner Login'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 70),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
