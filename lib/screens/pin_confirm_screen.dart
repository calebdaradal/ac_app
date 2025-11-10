import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../services/pin_storage.dart';
import 'home_screen.dart';
import '../shared/numeric_keypad.dart';

class PinConfirmScreen extends StatefulWidget {
  static const routeName = '/pin-confirm';
  const PinConfirmScreen({super.key});

  @override
  State<PinConfirmScreen> createState() => _PinConfirmScreenState();
}

class _PinConfirmScreenState extends State<PinConfirmScreen> {
  String _pin = '';
  String? _error;

  void _tap(String value, String expected) async {
    if (value == '←') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() => _pin += value);
    if (_pin.length == 4) {
      if (_pin == expected) {
        await PinStorage.savePin(_pin);
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, HomeScreen.routeName, (_) => false);
        }
      } else {
        setState(() {
          _error = 'PINs do not match';
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expected = ModalRoute.of(context)!.settings.arguments as String? ?? '';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white,),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
    
          SvgPicture.asset('assets/img/logo/OrangeLeaf.svg', width: 90,),
    
          const SizedBox(height: 30),
    
          TitleText('Confirm your PIN', fontSize: 30, color: AppColors.titleColor),
    
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
              onTap: (v) => _tap(v, expected),
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

// old keypad implementation removed in favor of shared NumericKeypad


