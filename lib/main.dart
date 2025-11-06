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
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load environment variables from .env (bundled as an asset)
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? 'https://YOUR-PROJECT-REF.supabase.co',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'YOUR-ANON-KEY',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AC App',
      debugShowCheckedModeBanner: false,
      theme: primaryTheme,
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
      },
    );
  }
}
