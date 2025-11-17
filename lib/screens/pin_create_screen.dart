import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'pin_confirm_screen.dart';
import '../shared/numeric_keypad.dart';

class PinCreateScreen extends StatefulWidget {
  static const routeName = '/pin-create';
  const PinCreateScreen({super.key});

  @override
  State<PinCreateScreen> createState() => _PinCreateScreenState();
}

class _PinCreateScreenState extends State<PinCreateScreen> {
  String _pin = '';

  void _tap(String value) {
    if (value == '←') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= 4) return;
    setState(() => _pin += value);
    if (_pin.length == 4) {
      // Get the isUpdating flag from route arguments
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final isUpdating = args?['isUpdating'] ?? false;
      
      Navigator.pushNamed(
        context,
        PinConfirmScreen.routeName,
        arguments: {
          'pin': _pin,
          'isUpdating': isUpdating,
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar( backgroundColor: Colors.white,),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/img/logo/OrangeLeaf.svg', width: 90,),
            
            const SizedBox(height: 30),
            
            TitleText(
              ModalRoute.of(context)?.settings.arguments != null &&
                  (ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>)['isUpdating'] == true
                  ? 'Create new PIN'
                  : 'Create your PIN',
              fontSize: 30,
              color: AppColors.titleColor,
            ),
            
            const SizedBox(height: 30,),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => _Dot(filled: i < _pin.length)),
            ),
            
            const SizedBox(height: 24),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: NumericKeypad(
                onTap: _tap,
                diameter: 89, // adjust to taste
                spacing: 28,
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


