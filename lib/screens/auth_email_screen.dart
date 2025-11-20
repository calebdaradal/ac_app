import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/shared/styled_textfield.dart';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/otp_session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'otp_screen.dart';

class AuthEmailScreen extends StatefulWidget {
  static const routeName = '/auth-email';
  const AuthEmailScreen({super.key});

  @override
  State<AuthEmailScreen> createState() => _AuthEmailScreenState();
}

class _AuthEmailScreenState extends State<AuthEmailScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _error;
  final FocusNode _emailFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      setState(() {

      }); // triggers rebuild when focus changes
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleRequestOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    
    setState(() {
      _loading = true;
      _error = null;
    });
    
    // SECURITY CHECK: Check is_active in profiles table - MUST HAPPEN FIRST
    // This check MUST complete successfully before any OTP logic runs
    final supabase = Supabase.instance.client;
    bool securityCheckPassed = false;
    
    try {
      // Query profiles table to check is_active - this MUST work
      final profileResponse = await supabase
          .from('profiles')
          .select('is_active')
          .eq('email', email.toLowerCase().trim())
          .maybeSingle();
      
      print('[AuthEmailScreen] Security check for: $email');
      print('[AuthEmailScreen] Response: $profileResponse');
      
      // If profile exists in database, check is_active
      if (profileResponse != null) {
        final isActive = profileResponse['is_active'];
        print('[AuthEmailScreen] is_active value: $isActive (type: ${isActive.runtimeType})');
        
        // CRITICAL CHECK: if is_active is false, block immediately
        if (isActive == false) {
          print('[AuthEmailScreen] *** SECURITY BLOCK: User is disabled ***');
          if (mounted) {
            setState(() {
              _error = 'Sorry this email is not available anymore';
              _loading = false;
            });
          }
          return; // STOP HERE - DO NOT PROCEED TO OTP
        }
        
        // User is active (true or null which defaults to true)
        print('[AuthEmailScreen] User is active - security check passed');
        securityCheckPassed = true;
      } else {
        // Profile doesn't exist - new signup allowed
        print('[AuthEmailScreen] Profile not found (new signup) - allowing');
        securityCheckPassed = true;
      }
    } catch (e, stackTrace) {
      print('[AuthEmailScreen] CRITICAL ERROR checking profile: $e');
      print('[AuthEmailScreen] Stack trace: $stackTrace');
      // If we can't verify, BLOCK for security (fail-secure)
      if (mounted) {
        setState(() {
          _error = 'Unable to verify account. Please try again.';
          _loading = false;
        });
      }
      return; // STOP - do not proceed if check fails
    }
    
    // DOUBLE CHECK: Only proceed if security check passed
    if (!securityCheckPassed) {
      print('[AuthEmailScreen] Security check failed - blocking');
      if (mounted) {
        setState(() {
          _error = 'Sorry this email is not available anymore';
          _loading = false;
        });
      }
      return; // STOP - do not proceed
    }
    
    // Security check passed - now proceed with OTP logic
    
    // User is active - proceed with OTP
    try {
      // Check if there's a valid existing OTP session for this email
      final remainingSeconds = OtpSessionService.getValidSessionRemainingSeconds(email);
      if (remainingSeconds != null) {
        // Valid session exists - navigate directly to OTP screen without requesting new OTP
        final sessionTimestamp = OtpSessionService.getSessionTimestamp(email);
        if (mounted) {
          setState(() => _loading = false);
          Navigator.pushNamed(
            context, 
            OtpScreen.routeName, 
            arguments: {
              'email': email,
              'timestamp': sessionTimestamp?.millisecondsSinceEpoch,
            },
          );
        }
        return;
      }
      
      // No valid session - request new OTP
      await SupabaseService.requestOtp(email);
      if (mounted) {
        setState(() => _loading = false);
        Navigator.pushNamed(
          context, 
          OtpScreen.routeName, 
          arguments: {
            'email': email,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to request OTP. Make sure the email exists.';
          _loading = false;
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
  
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        
              TitleText('Welcome Back!'),
              const SizedBox(height: 8),
              SecondaryText('Insert your account details to continue', fontSize: 15,),
        
              const SizedBox(height: 17),
        
              StyledTextfield(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                label: 'Enter email',
                focusNode: _emailFocusNode,
              ),
        
              const SizedBox(height: 16),
        
              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        
              const SizedBox(height: 16),
        
              
              
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SecondaryText('By continuing you adhere to our ', fontSize: 14, color: Color.fromRGBO(34, 43, 69, 1)),
        
                        GestureDetector(
                          onTap: () {},
                          child: PrimaryText('Terms of Use', fontSize: 14)
                        )
                    ],
                    ),
            
                    const SizedBox(height: 15),
        
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            onPressed: (_loading || _emailFocusNode.hasFocus) ? null : () => _handleRequestOtp(),
                            child: _loading ? const CircularProgressIndicator() : const PrimaryTextW('Continue'),
                          ),
                        )
                      ],
                    ),
                    
                  ],
                ),
              ),
        
              const SizedBox(height: 30)
            ],
          ),
        ),
      ),
    );
  }
}


