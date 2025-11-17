import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';

import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../services/pin_storage.dart';
import '../services/user_profile_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import '../shared/numeric_keypad.dart';

class PinUnlockScreen extends StatefulWidget {
  static const routeName = '/pin-unlock';
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  String _pin = '';
  String? _error;
  String? _storedPin;

  @override
  void initState() {
    super.initState();
    _loadStoredPin();
  }

  Future<void> _loadStoredPin() async {
    final value = await PinStorage.readPin();
    if (mounted) setState(() => _storedPin = value);
  }

  void _tap(String value) async {
    if (value == '←') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() => _pin += value);
    if (_pin.length == 4) {
      bool isValid = false;
      
      // First try local PIN (fast)
      if (_storedPin != null && _pin == _storedPin) {
        isValid = true;
      } else {
        // If local PIN doesn't match or doesn't exist, check database
        try {
          isValid = await PinStorage.verifyPinWithDatabase(_pin);
          if (isValid) {
            // Cache the PIN locally for next time
            await PinStorage.savePin(_pin);
            if (mounted) setState(() => _storedPin = _pin);
          }
        } catch (e) {
          print('Error verifying PIN with database: $e');
        }
      }
      
      if (isValid) {
        // Always load fresh profile from database after PIN verification
        // This ensures we get the correct user's profile (not cached from previous user)
        final profileService = UserProfileService();
        try {
          // Clear any cached profile first to avoid loading wrong user's data
          await profileService.clearProfile();
          
          // Load fresh profile from database for the currently authenticated user
          await profileService.loadProfile();
          
          // Save UID locally for future reference
          final uid = profileService.profile?.uid;
          if (uid != null) {
            await PinStorage.saveUid(uid);
          }
          
          // Store device token for push notifications
          try {
            final deviceState = await OneSignal.User.pushSubscription.id;
            if (deviceState != null) {
              await NotificationService().storeDeviceToken(deviceState);
            }
          } catch (e) {
            print('[PinUnlock] Error storing device token: $e');
            // Don't show error to user - notifications are optional
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Warning: Could not load profile data: $e')),
            );
            return; // Don't navigate if profile load fails
          }
        }
        
        if (mounted) {
          Navigator.pushReplacementNamed(context, HomeScreen.routeName);
        }
      } else {
        setState(() {
          _error = 'Incorrect PIN';
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white,),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            Image.asset('assets/img/logo/OrangeLeaf.png'),
            
            const SizedBox(height: 30),
            
            TitleText('Enter your PIN', fontSize: 30, color: AppColors.titleColor),
            
            const SizedBox(height: 30,),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => _Dot(filled: i < _pin.length)),
            ),
            const SizedBox(height: 8),
            if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: NumericKeypad(
                onTap: _tap,
                diameter: 89,
                spacing: 16,
              ),
            ),
            
            const SizedBox(height: 50,),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool filled;
  const _Dot({required this.filled});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: filled ?BoxBorder.all(color: Color.fromRGBO(44, 100, 227, 1), width: 1) : BoxBorder.all(color: const Color.fromARGB(255, 185, 185, 185), width: 1,),
        color: filled ? const Color.fromRGBO(44, 100, 227, 1) : const Color.fromARGB(255, 255, 255, 255),
      ),
    );
  }
}


// old keypad implementation removed in favor of shared NumericKeypad


