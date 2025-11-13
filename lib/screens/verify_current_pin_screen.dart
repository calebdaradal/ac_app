import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';
import '../services/pin_storage.dart';
import '../shared/numeric_keypad.dart';
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
          _errorMessage = 'Incorrect PIN. Please try again.';
          _pin = '';
          _isVerifying = false;
        });
      }
    } catch (e) {
      print('[VerifyCurrentPin] Error during verification: $e');
      setState(() {
        _errorMessage = 'Error verifying PIN. Please try again.';
        _pin = '';
        _isVerifying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.titleColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              
              // Logo
              SvgPicture.asset(
                'assets/img/logo/OrangeLeaf.svg',
                width: 90,
              ),
              
              const SizedBox(height: 40),
              
              // Title
              const Text(
                'Verify Current PIN',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'Enter your current PIN to continue',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF718096),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length
                          ? AppColors.primaryColor
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              
              const Spacer(),
              
              // Numeric Keypad
              if (_isVerifying)
                const CircularProgressIndicator()
              else
                NumericKeypad(
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
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

