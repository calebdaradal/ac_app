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
      style: GoogleFonts.rubik().copyWith(
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
    // Check if text contains peso symbol
    if (text.contains('₱')) {
      // Use TextSpan to apply different fonts for peso symbol vs regular text
      final textColor = color ?? AppColors.secondaryTextColor;
      final baseFontSize = fontSize ?? 18;
      
      final textSpans = <TextSpan>[];
      final rubikStyle = GoogleFonts.rubik().copyWith(
        color: textColor,
        fontSize: baseFontSize,
      );
      
      final pesoStyle = TextStyle(
        fontFamily: '.SF Pro Text', // iOS system font that supports ₱
        fontFamilyFallback: ['Roboto', 'Arial', 'sans-serif'], // Fallbacks
        color: textColor,
        fontSize: baseFontSize,
      );
      
      // Split text and rebuild with appropriate fonts
      int lastIndex = 0;
      for (int i = 0; i < text.length; i++) {
        if (text[i] == '₱') {
          // Add text before peso symbol with Rubik
          if (i > lastIndex) {
            textSpans.add(
              TextSpan(
                text: text.substring(lastIndex, i),
                style: rubikStyle,
              ),
            );
          }
          // Add peso symbol with system font
          textSpans.add(
            TextSpan(
              text: '₱',
              style: pesoStyle,
            ),
          );
          lastIndex = i + 1;
        }
      }
      
      // Add remaining text with Rubik
      if (lastIndex < text.length) {
        textSpans.add(
          TextSpan(
            text: text.substring(lastIndex),
            style: rubikStyle,
          ),
        );
      }
      
      return Text.rich(
        TextSpan(children: textSpans),
      );
    }
    
    // Regular text without peso symbol - use Rubik
    return Text(
      text,
      style: GoogleFonts.rubik().copyWith(
        color: color ?? AppColors.secondaryTextColor,
        fontSize: fontSize ?? 18,
      ),
    );
  }
}

class PrimaryTextW extends StatelessWidget {
  const PrimaryTextW(this.text, { this.decoration, this.fontSize, this.letterSpacing, super.key});
  final String text;
  final TextDecoration? decoration;
  final double? fontSize;
  final double? letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.rubik().copyWith(
        color: Colors.white,
        fontSize: fontSize?? 18,
        letterSpacing: letterSpacing?? 0.4,
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
    // Check if text contains peso symbol
    if (text.contains('₱')) {
      // Use TextSpan to apply different fonts for peso symbol vs regular text
      final textColor = color ?? AppColors.titleColor;
      final baseFontSize = fontSize ?? 32;
      
      final textSpans = <TextSpan>[];
      final rubikStyle = GoogleFonts.rubik().copyWith(
        color: textColor,
        fontSize: baseFontSize,
        decoration: decoration,
        decorationColor: Colors.white,
        fontWeight: FontWeight.bold,
      );
      
      final pesoStyle = TextStyle(
        fontFamily: '.SF Pro Text', // iOS system font that supports ₱
        fontFamilyFallback: ['Roboto', 'Arial', 'sans-serif'], // Fallbacks
        color: textColor,
        fontSize: baseFontSize,
        decoration: decoration,
        decorationColor: Colors.white,
        fontWeight: FontWeight.bold,
      );
      
      // Split text and rebuild with appropriate fonts
      int lastIndex = 0;
      for (int i = 0; i < text.length; i++) {
        if (text[i] == '₱') {
          // Add text before peso symbol with Rubik
          if (i > lastIndex) {
            textSpans.add(
              TextSpan(
                text: text.substring(lastIndex, i),
                style: rubikStyle,
              ),
            );
          }
          // Add peso symbol with system font
          textSpans.add(
            TextSpan(
              text: '₱',
              style: pesoStyle,
            ),
          );
          lastIndex = i + 1;
        }
      }
      
      // Add remaining text with Rubik
      if (lastIndex < text.length) {
        textSpans.add(
          TextSpan(
            text: text.substring(lastIndex),
            style: rubikStyle,
          ),
        );
      }
      
      return Text.rich(
        TextSpan(children: textSpans),
      );
    }
    
    // Regular text without peso symbol - use Rubik
    return Text(
      text,
      style: GoogleFonts.rubik().copyWith(
        color: color ?? AppColors.titleColor,
        fontSize: fontSize ?? 32,
        decoration: decoration,
        decorationColor: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}