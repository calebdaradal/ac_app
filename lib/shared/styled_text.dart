import 'package:ac_app/theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrimaryText extends StatelessWidget {
  const PrimaryText(this.text, {this.fontSize, this.color, super.key});
  final String text;
  final double? fontSize;  
  final dynamic color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.getTextTheme('Afacad').bodyMedium?.copyWith(
        color: color ?? AppColors.primaryColor,
        fontSize: fontSize ?? 18,
      ),
    );
  }
}

class SecondaryText extends StatelessWidget {
  const SecondaryText(this.text, {this.fontSize, this.color, super.key});
  final String text;
  final double? fontSize;
  final dynamic color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.getTextTheme('Afacad').bodyMedium?.copyWith(
        color: color ?? AppColors.secondaryTextColor,
        fontSize: fontSize ?? 18,
      ),
    );
  }
}

class PrimaryTextW extends StatelessWidget {
  const PrimaryTextW(this.text, { this.decoration, super.key});
  final String text;
  final TextDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.getTextTheme('Afacad').bodyMedium?.copyWith(
        color: Colors.white,
        fontSize: 18,
        decoration: decoration,
        decorationColor: Colors.white
      ),
    );
  }
}
class TitleText extends StatelessWidget {
  const TitleText(this.text, { this.decoration, this.color, this.fontSize, super.key});
  final String text;
  final TextDecoration? decoration;
  
  final dynamic color;
  
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.getTextTheme('Afacad').bodyMedium?.copyWith(
        color: color ?? AppColors.titleColor,
        fontSize: fontSize ?? 32,
        decoration: decoration,
        decorationColor: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}