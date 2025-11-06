import 'package:ac_app/shared/styled_button.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/shared/styled_textfield.dart';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
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
    try {
      await SupabaseService.requestOtp(email);
      if (mounted) {
        Navigator.pushNamed(context, OtpScreen.routeName, arguments: email);
      }
    } catch (e) {
      setState(() => _error = 'Failed to request OTP. Make sure the email exists.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white,),
      body: Padding(
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
                      SecondaryText('By Continuing you adhere to our ', fontSize: 14, color: Color.fromRGBO(34, 43, 69, 1)),

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
    );
  }
}


