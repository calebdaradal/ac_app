import 'package:ac_app/shared/styled_pin_input.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';

import '../services/supabase_service.dart';
import '../services/pin_storage.dart';
import '../services/otp_session_service.dart';
import 'pin_create_screen.dart';
import 'pin_unlock_screen.dart';

class OtpScreen extends StatefulWidget {
  static const routeName = '/otp';
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  String _code = '';
  bool _loading = false;
  String? _error;
  int _secondsLeft = 60;
  Timer? _timer;
  String? _email;
  bool _notifiedResendAvailable = false;
  bool _resendCooldown = false;

  Future<void> _verify(String email) async {
    if (_code.length != 6) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SupabaseService.verifyOtp(email: email, token: _code);
      
      if (mounted) {
        // Clear the OTP session after successful verification
        OtpSessionService.clearSession();
        
        // Check if user already has a PIN in the database
        final hasPinInDb = await PinStorage.hasPinInDatabase();
        print('[OTP] User has PIN in database: $hasPinInDb');
        
        if (hasPinInDb) {
          // Existing user - go to unlock screen
          Navigator.pushReplacementNamed(context, PinUnlockScreen.routeName);
        } else {
          // New user - create PIN
          Navigator.pushReplacementNamed(context, PinCreateScreen.routeName);
        }
      }
    } catch (e) {
      setState(() => _error = 'Invalid OTP');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Don't start timer here - wait for didChangeDependencies to get the timestamp
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments;
    
    if (args is Map) {
      // New format: arguments is a map with email and timestamp
      _email ??= args['email'] as String?;
      final timestampMs = args['timestamp'] as int?;
      if (timestampMs != null) {
        // Calculate remaining seconds based on original timestamp
        final originalTimestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
        final elapsed = DateTime.now().difference(originalTimestamp);
        final remaining = 60 - elapsed.inSeconds;
        _secondsLeft = remaining > 0 ? remaining : 0;
      }
    } else if (args is String) {
      // Legacy format: arguments is just the email string
      _email ??= args;
    }
    
    // Start timer after setting up the initial state
    // Only reset to 60 if we don't have a restored timestamp
    if (_timer == null) {
      final args = ModalRoute.of(context)!.settings.arguments;
      final hasTimestamp = args is Map && args['timestamp'] != null;
      _startTimer(resetTo60: !hasTimestamp);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer({bool resetTo60 = false}) {
    if (resetTo60) {
      _secondsLeft = 60;
    }
    _notifiedResendAvailable = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        setState(() => _secondsLeft = 0);
        t.cancel();
        _notifiedResendAvailable = true;
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  void _showResendToast([String message = 'You can resend the code now']) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primaryColor,
          content: Text(message),
          behavior: SnackBarBehavior.fixed,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  String _format(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  Future<void> _resend() async {
    if (_email == null) return;
    if (_resendCooldown) return;
    setState(() {
      _error = null;
      _loading = true;
      _resendCooldown = true;
    });
    try {
      await SupabaseService.requestOtp(_email!);
      // Get the new timestamp for the timer
      final newTimestamp = OtpSessionService.getSessionTimestamp(_email!);
      if (newTimestamp != null) {
        // Calculate remaining seconds from the new timestamp
        final elapsed = DateTime.now().difference(newTimestamp);
        final remaining = 60 - elapsed.inSeconds;
        _secondsLeft = remaining > 0 ? remaining : 0;
        // Restart timer with the calculated remaining time
        _startTimer(resetTo60: false);
      } else {
        _startTimer(resetTo60: true);
      }
      _showResendToast('Code sent. Check your email');
    } catch (e) {
      setState(() => _error = 'Failed to resend code');
    } finally {
      if (mounted) setState(() => _loading = false);
      // Keep link greyed out briefly after tap
      await Future.delayed(const Duration(milliseconds: 10));
      if (mounted) setState(() => _resendCooldown = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white,),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
            
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TitleText('Verify OTP'),
                    const SizedBox(height: 12),
                     Row(
                      children: [
                        SecondaryText('Code is sent to ', fontSize: 16,),
                         SecondaryText(_email ?? '', color: AppColors.titleColor, fontSize: 16,),
                      ],
                    )
                  ],
                )
              ),
            
              
            
              const SizedBox(height: 24),
            
              StyledPinput(
                 onChanged: (v) => _code = v,
                 onCompleted: (_) => _verify(_email ?? ''),
                keyboardType: TextInputType.number,
              ),
            
              const SizedBox(height: 16),
            
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
            
              const SizedBox(height: 16),
            
              // Resend section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SecondaryText('Didn\'t get the code? ' ),
                  if (_secondsLeft > 0)
                    PrimaryText('Resend in ${_format(_secondsLeft)}')
                  else
                     GestureDetector(
                       onTap: _loading || _resendCooldown ? null : _resend,
                       child: PrimaryText(
                         'Resend code',
                         color: _resendCooldown ? AppColors.secondaryTextColor : AppColors.primaryColor,
                       ),
                     ),
                ],
              )
              
            
              // SizedBox(
              //   width: double.infinity,
              //   child: ElevatedButton(
              //     onPressed: _loading ? null : () => _verify(email ?? ''),
              //     child: _loading ? const CircularProgressIndicator() : const Text('Verify'),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}


