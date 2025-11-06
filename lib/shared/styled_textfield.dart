import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';

class StyledTextfield extends StatelessWidget {
  const StyledTextfield({required this.controller, required this.keyboardType, required this.label, this.focusNode, super.key});

  final dynamic controller;
  final dynamic keyboardType;
  final String label;
  final dynamic focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: focusNode,
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.titleColor.withOpacity(0.5),
        ),
        filled: true,
        fillColor: const Color.fromRGBO(247, 249, 252, 1),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.transparent, width: 0),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
        ),
      )
    );
  }
}