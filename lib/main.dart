import 'package:ac_app/screens/vehicles/deposit_screen.dart';
import 'package:ac_app/screens/vehicles/withdraw_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/welcome_screen.dart';
import 'screens/auth_email_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/pin_create_screen.dart';
import 'screens/pin_confirm_screen.dart';
import 'screens/home_screen.dart';
import 'screens/pin_unlock_screen.dart';
import 'screens/vehicles/asc_screen.dart';
import 'screens/vehicles/stk_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/admin_verification_screen.dart';
import 'screens/create_user_screen.dart';
import 'screens/manage_banks_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/verify_current_pin_screen.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables from .env (bundled as an asset)
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? 'https://YOUR-PROJECT-REF.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'YOUR-ANON-KEY',
  );
  
  // Initialize OneSignal notifications (non-blocking)
  // This will only work if ONESIGNAL_APP_ID is set in .env
  NotificationService().initialize().catchError((error) {
    print('[main] Failed to initialize notifications: $error');
    // Continue app startup even if notifications fail
  });
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    // Set navigator key for notification navigation
    NotificationService().setNavigatorKey(_navigatorKey);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Ascendo Capital',
      debugShowCheckedModeBanner: false,
      theme: primaryTheme,
      // initialRoute: WelcomeScreen.routeName,
      initialRoute: WelcomeScreen.routeName,
      // initialRoute: PinUnlockScreen.routeName,

      routes: {
        WelcomeScreen.routeName: (_) => const WelcomeScreen(),
        AuthEmailScreen.routeName: (_) => const AuthEmailScreen(),
        OtpScreen.routeName: (_) => const OtpScreen(),
        PinCreateScreen.routeName: (_) => const PinCreateScreen(),
        PinConfirmScreen.routeName: (_) => const PinConfirmScreen(),
        PinUnlockScreen.routeName: (_) => const PinUnlockScreen(),
        HomeScreen.routeName: (_) => const HomeScreen(),
        AscScreen.routeName: (_) => const AscScreen(),
        StkScreen.routeName: (_) => const StkScreen(),
        AdminScreen.routeName: (_) => const AdminScreen(),
        AdminVerificationScreen.routeName: (_) => const AdminVerificationScreen(),
        CreateUserScreen.routeName: (_) => const CreateUserScreen(),
        ManageBanksScreen.routeName: (_) => const ManageBanksScreen(),
        DepositFunds.routeName: (_) => const DepositFunds(),
        WithdrawFunds.routeName: (_) => const WithdrawFunds(),
        ProfileScreen.routeName: (_) => const ProfileScreen(),
        VerifyCurrentPinScreen.routeName: (_) => const VerifyCurrentPinScreen(),
      },
    );
  }
}