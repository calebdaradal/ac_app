import 'package:ac_app/services/investment_service.dart';
import 'package:ac_app/shared/styled_card.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../services/pin_storage.dart';
import '../services/user_profile_service.dart';
import '../services/notification_service.dart';
import 'admin_screen.dart';
import 'welcome_screen.dart';
import 'vehicles/asc_screen.dart';
import 'vehicles/stk_screen.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/home';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  AggregatedSubscriptions? _aggregatedData;
  VehicleSummary? _affSummary;
  VehicleSummary? _stkSummary;
  bool _loading = true;
  int _avatarRefreshKey = 0; // Increment this to force image reload

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    // Ensure profile is loaded before fetching data
    try {
      final profileService = UserProfileService();
      if (profileService.profile == null) {
        await profileService.loadProfile();
      }
      
      // Ensure device token is registered for the current user
      // This is a safety measure in case token registration failed during PIN unlock
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final deviceState = await OneSignal.User.pushSubscription.id;
          if (deviceState != null) {
            print('[HomeScreen] Ensuring device token is registered for user ${user.id}');
            await NotificationService().storeDeviceToken(deviceState);
          } else {
            print('[HomeScreen] ⚠️ Device token not available yet');
          }
        }
      } catch (e) {
        print('[HomeScreen] Error ensuring device token registration: $e');
        // Don't show error to user - notifications are optional
      }
    } catch (e) {
      print('[HomeScreen] Error loading profile: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    await Future.wait([
      _loadAggregatedData(),
      _loadVehicleSummaries(),
    ]);
  }

  Future<void> _loadAggregatedData() async {
    try {
      final data = await InvestmentService.getAllSubscriptions();
      if (mounted) {
        setState(() {
          _aggregatedData = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        // Silently fail - just show zeros
      }
    }
  }

  Future<void> _loadVehicleSummaries() async {
    try {
      // Load both vehicle summaries in parallel
      final results = await Future.wait([
        InvestmentService.getVehicleSummary('AFF'),
        InvestmentService.getVehicleSummary('STK'),
      ]);

      if (mounted) {
        setState(() {
          _affSummary = results[0];
          _stkSummary = results[1];
        });
      }
    } catch (e) {
      print('[HomeScreen] Error loading vehicle summaries: $e');
      // Silently fail - cards will show 0 values
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'No updates yet';
    return DateFormat('MM/dd/yyyy').format(date);
  }

  Future<void> _signOut(BuildContext context) async {
    // Remove device token BEFORE signing out (so we have the user ID)
    try {
      await NotificationService().removeDeviceToken();
    } catch (e) {
      print('[HomeScreen] Error removing device token: $e');
      // Continue with logout even if token removal fails
    }
    
    // Sign out from Supabase
    await Supabase.instance.client.auth.signOut();
    
    // Clear all cached data to prevent cross-user authentication issues
    await PinStorage.clearPin();
    await PinStorage.clearUid();
    await UserProfileService().clearProfile();
    
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        WelcomeScreen.routeName,
        (_) => false,
      );
    }
  }

  Future<void> _refreshProfile() async {
    try {
      await UserProfileService().refreshProfile();
      if (mounted) {
        setState(() {
          // Increment refresh key to force image reload
          _avatarRefreshKey++;
        });
      }
    } catch (e) {
      print('[HomeScreen] Error refreshing profile: $e');
    }
  }

  void _showFAQDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.primaryColor),
              const SizedBox(width: 12),
              const TitleText('FAQ', fontSize: 20),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: _FAQAccordion(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = UserProfileService().profile;
    final avatarUrl = profile?.avatarUrl;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 90,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        // leadingWidth: 72,
        flexibleSpace: SafeArea(
          bottom: false,
          child: Padding(
          padding: const EdgeInsets.only(left: 12, top: 12, bottom: 12, right: 16),
          child: Row(
            children: [
              InkWell(
                borderRadius: BorderRadius.all(Radius.circular(10)),
                highlightColor: Colors.grey.withOpacity(0.5),
                onTap: () async {
                  await Navigator.pushNamed(context, '/profile');
                  // Refresh profile when returning from profile screen
                  await _refreshProfile();
                },
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8, right: 15),
                  child: Row(
                    children: [

                      SizedBox(width: 8),
    
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: avatarUrl != null
                              ? Image.network(
                                  avatarUrl,
                                  key: ValueKey('${avatarUrl}_$_avatarRefreshKey'),
                                  fit: BoxFit.cover,
                                  width: 50,
                                  height: 50,
                                  errorBuilder: (context, error, stackTrace) {
                                    print('[HomeScreen] Error loading avatar: $error');
                                    print('[HomeScreen] Avatar URL: $avatarUrl');
                                    return Image.asset(
                                      'assets/img/sample/placeholder.png',
                                      fit: BoxFit.cover,
                                      width: 60,
                                      height: 60,
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Image.asset(
                                      'assets/img/sample/placeholder.png',
                                      fit: BoxFit.cover,
                                      width: 60,
                                      height: 60,
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/img/sample/placeholder.png',
                                  fit: BoxFit.cover,
                                  width: 60,
                                  height: 60,
                                ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            TitleText(
                              profile?.fullName ?? 'User',
                              fontSize: 18,
                              color: AppColors.titleColor,
                            ),
                            PrimaryText(
                              profile?.email ?? '',
                              fontSize: 14,
                              color: AppColors.secondaryTextColor,
                            )
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
                  // InkWell(
                  //   onTap: () {},
                  //   borderRadius: BorderRadius.all(Radius.circular(25)),
                  //   highlightColor: Colors.white,
                  //   child: Padding(
                  //     padding: const EdgeInsets.all(4.0),
                  //     child: SvgPicture.asset(
                  //       'assets/img/icons/notification.svg',
                  //       width: 29,
                  //       ),
                  //   ),
                  // ),
    
                  // const SizedBox(width: 3,),
    
                    PopupMenuButton<String>(
                      icon: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: SvgPicture.asset(
                        'assets/img/icons/settings.svg',
                        width: 29,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      offset: const Offset(0, 50),
                      onSelected: (value) {
                        if (value == 'logout') {
                          _signOut(context);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'logout',
                          child: Row(
                            children: [
                              Icon(
                                Icons.logout,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Admin button - only visible for admin users
                    if (profile?.isAdmin == true)
                      InkWell(
                        onTap: () {
                          Navigator.pushNamed(context, AdminScreen.routeName);
                        },
                        borderRadius: BorderRadius.all(Radius.circular(25)),
                        highlightColor: Colors.red.withOpacity(0.2),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(
                            Icons.admin_panel_settings,
                            size: 29,
                            color: Colors.red.shade700,
                        ),
                    ),
                  ),
                ],
              )
            ],
          ),
    
        ),
        ),
        ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadAllData,
        color: AppColors.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          // mainAxisSize: MainAxisSize.min,
          
          children: [
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TitleText('Account Summary', color: Colors.grey, fontSize: 19,),
    
                HomeCard(
                      totalContributions: _aggregatedData?.totalContributions ?? 0.0,
                      yield: _aggregatedData?.yieldPercentage ?? 0.0,
                      currentBalance: _aggregatedData?.currentBalance ?? 0.0,
                      totalYield: _aggregatedData?.totalYield ?? 0.0,
                ),
                
                // FAQ Card
                AFFCard(
                  title: 'FAQ',
                  yield: 0.0,
                  date: 'Frequently Asked Questions',
                  onTap: () {
                    _showFAQDialog(context);
                  },
                  color: const Color.fromRGBO(255, 152, 0, 1), // Vibrant orange color
                ),
                
                AFFCard(
                  title: 'Ascendo Futures Fund',
                  yield: _affSummary?.latestYieldPercent ?? 0.0,
                  date: _formatDate(_affSummary?.lastUpdated),
                  onTap: () {
                    Navigator.pushNamed(context, AscScreen.routeName);
                  },
                  color: AppColors.primaryColor,
                ),

                AFFCard(
                  title: 'SOL/ETH Staking Pool',
                  yield: _stkSummary?.latestYieldPercent ?? 0.0,
                  date: _formatDate(_stkSummary?.lastUpdated),
                  onTap: () {
                    Navigator.pushNamed(context, StkScreen.routeName);
                  },
                  color: AppColors.tertiaryColor
                ),
    
                DiscoverCard(
                  color: AppColors.secondaryColor,
                  title: 'Discover more opportunities',
                  onTap: () {},
                  enabled: false,
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
        ),
      ),
    );
  }
}

class _FAQAccordion extends StatefulWidget {
  @override
  State<_FAQAccordion> createState() => _FAQAccordionState();
}

class _FAQAccordionState extends State<_FAQAccordion> {
  int? _expandedIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFAQItem(
          index: 0,
          title: 'Gate Penalties',
          content: '''A 5% fee applies when withdrawing 33.33% or more of your balance.

Example: Withdrawing ₱7,000 from ₱9,800 balance triggers a ₱350 gate penalty.

Applies on all dates, including redemption dates.''',
        ),
        const SizedBox(height: 12),
        _buildFAQItem(
          index: 1,
          title: 'Redemption Penalties',
          content: '''A 5% fee applies when withdrawing on non-redemption dates.

Redemption dates: March 30-31, June 29-30, September 29-30, December 30-31

Example: Withdrawing ₱5,000 on a regular day triggers a ₱250 redemption penalty.

Tip: Withdraw on redemption dates to avoid this penalty. Gate penalties may still apply if withdrawing 33.33% or more.''',
        ),
      ],
    );
  }

  Widget _buildFAQItem({
    required int index,
    required String title,
    required String content,
  }) {
    final isExpanded = _expandedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? AppColors.primaryColor : Colors.grey.shade300,
          width: isExpanded ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedIndex = isExpanded ? null : index;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TitleText(
                      title,
                      fontSize: 16,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Column(
                    children: [
                      Divider(height: 1, color: Colors.grey.shade300),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SecondaryText(
                          content,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}


