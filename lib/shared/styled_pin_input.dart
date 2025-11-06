import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';

class StyledPinput extends StatelessWidget {
  const StyledPinput({super.key, required this.onChanged, required this.onCompleted, required this.keyboardType});

  final dynamic onChanged;
  
  final dynamic onCompleted;
  
  final dynamic keyboardType;

  @override
  Widget build(BuildContext context) {
    return Pinput(
      length: 6,
      defaultPinTheme: PinTheme(
        width: 48,
        height: 56,
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.all(Radius.circular(10))
        )
      ),
      separatorBuilder: (index) {
        if (index == 2) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('-', style: TextStyle(fontSize: 40, color: Colors.grey)),
          );
        }
        return const SizedBox(width: 8); // default spacing
      },
      focusedPinTheme: PinTheme(
        width: 48,
        height: 56,
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        decoration: BoxDecoration(
          color: AppColors.primaryColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Color.fromRGBO(66, 170, 255, 1), width: 2),
        ),
      ),
      submittedPinTheme: PinTheme(
        width: 48,
        height: 56,
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppColors.primaryColor.withOpacity(0.06),
          border: Border.all(color: AppColors.primaryColor),
        ),
      ),
      onChanged: onChanged,
      onCompleted: onCompleted,
      keyboardType: keyboardType,
    );
  }
}