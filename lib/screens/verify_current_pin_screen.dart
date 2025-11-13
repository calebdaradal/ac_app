import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import '../theme.dart';
import '../services/pin_storage.dart';
import '../shared/numeric_keypad.dart';
import '../shared/styled_text.dart';
import 'pin_create_screen.dart';

class VerifyCurrentPinScreen extends StatefulWidget {
  static const routeName = '/verify-current-pin';
  
  const VerifyCurrentPinScreen({super.key});

  @override
  State<VerifyCurrentPinScreen> createState() => _VerifyCurrentPinScreenState();
}

class _VerifyCurrentPinScreenState extends State<VerifyCurrentPinScreen> {
  String _pin = '';
  bool _isVerifying = false;
  String? _errorMessage;

  void _onDigitEntered(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _errorMessage = null;
      });

      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);

    try {
      print('[VerifyCurrentPin] Verifying PIN: $_pin');
      
      // Hash the entered PIN
      final hashedEnteredPin = PinStorage.hashPin(_pin);
      print('[VerifyCurrentPin] Hashed entered PIN: $hashedEnteredPin');
      
      // First try local PIN (compare hashed versions)
      final storedPin = await PinStorage.readPin();
      bool isValid = false;

      if (storedPin != null) {
        final hashedStoredPin = PinStorage.hashPin(storedPin);
        print('[VerifyCurrentPin] Comparing with local PIN');
        if (hashedStoredPin == hashedEnteredPin) {
          print('[VerifyCurrentPin] Local PIN matches');
          isValid = true;
        }
      }
      
      if (!isValid) {
        // Try database PIN (verifyPinWithDatabase already handles hashing internally)
        print('[VerifyCurrentPin] Checking database PIN');
        isValid = await PinStorage.verifyPinWithDatabase(_pin);
        print('[VerifyCurrentPin] Database verification result: $isValid');
      }

      if (isValid) {
        // PIN verified, navigate to create new PIN screen
        print('[VerifyCurrentPin] PIN verified successfully');
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            PinCreateScreen.routeName,
            arguments: {'isUpdating': true}, // Pass flag to indicate this is an update
          );
        }
      } else {
        print('[VerifyCurrentPin] PIN verification failed');
        setState(() {
          _errorMessage = 'Incorrect PIN';
          _pin = '';
          _isVerifying = false;
        });
      }
    } catch (e) {
      print('[VerifyCurrentPin] Error during verification: $e');
      setState(() {
        _errorMessage = 'Error verifying PIN';
        _pin = '';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white,),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/img/logo/OrangeLeaf.svg', width: 90,),
    
          const SizedBox(height: 30),
    
          TitleText(
            'Verify Current PIN',
            fontSize: 30,
            color: AppColors.titleColor,
          ),
    
          const SizedBox(height: 30,),
    
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) => _Dot(filled: i < _pin.length)),
          ),
    
          const SizedBox(height: 8),
    
          if (_errorMessage != null) Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 24),
    
          // Numeric Keypad
          if (_isVerifying)
            const CircularProgressIndicator()
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: NumericKeypad(
                onTap: (value) {
                  if (value == '←') {
                    _onBackspace();
                  } else {
                    _onDigitEntered(value);
                  }
                },
                diameter: 89,
                spacing: 28,
              ),
            ),
    
          const SizedBox(height: 50,),
        ],
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

