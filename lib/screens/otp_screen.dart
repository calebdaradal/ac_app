import 'package:ac_app/shared/styled_pin_input.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import '../theme.dart';

import '../services/supabase_service.dart';
import '../services/pin_storage.dart';
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
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _email ??= ModalRoute.of(context)!.settings.arguments as String?;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft = 60;
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
      _startTimer();
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
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white,),
        body: Padding(
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


