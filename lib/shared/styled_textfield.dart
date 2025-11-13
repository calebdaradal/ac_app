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

class DigitField extends StatefulWidget {
  const DigitField({required this.controller, required this.keyboardType, required this.label, this.focusNode, super.key});

  final TextEditingController controller;
  final dynamic keyboardType;
  final String label;
  final dynamic focusNode;

  @override
  State<DigitField> createState() => _DigitFieldState();
}

class _DigitFieldState extends State<DigitField> {
  String _displayValue = '0.00';
  int _cents = 0;  // Store value in cents

  @override
  void initState() {
    super.initState();
    widget.controller.text = _displayValue;
  }

  String _formatWithCommas(int number) {
    // Format number with thousand separators
    final str = number.toString();
    final buffer = StringBuffer();
    int count = 0;
    
    // Add commas from right to left
    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
      count++;
    }
    
    return buffer.toString().split('').reversed.join('');
  }

  void _onDigitEntered(String value) {
    // Remove any non-digit characters
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      setState(() {
        _cents = 0;
        _displayValue = '0.00';
        widget.controller.text = _displayValue;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _displayValue.length),
        );
      });
      return;
    }

    // Parse the digits as cents value
    _cents = int.tryParse(digitsOnly) ?? 0;
    
    // Convert cents to formatted string with commas (e.g., 123456 cents = "1,234.56")
    final dollars = _cents ~/ 100;
    final cents = _cents % 100;
    final formattedDollars = _formatWithCommas(dollars);
    _displayValue = '$formattedDollars.${cents.toString().padLeft(2, '0')}';
    
    setState(() {
      widget.controller.text = _displayValue;
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _displayValue.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        color: const Color.fromRGBO(247, 249, 252, 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // PHP currency symbol - always visible, never deleted
          Text(
            '₱',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.titleColor,
            ),
          ),
          // Amount input field
          Flexible(
            child: IntrinsicWidth(
              child: TextField(
                focusNode: widget.focusNode,
                controller: widget.controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: AppColors.titleColor,
                ),
                onChanged: _onDigitEntered,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.transparent, width: 0),
                  ),
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.transparent, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                  isDense: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}