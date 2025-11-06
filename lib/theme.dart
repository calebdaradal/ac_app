import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static Color primaryColor = const Color.fromRGBO(255, 117, 31, 1);
  static Color titleColor = const Color.fromRGBO(34, 43, 69, 1);
  static Color secondaryTextColor = const Color.fromRGBO(143, 155, 179, 1);
}

ThemeData primaryTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primaryColor,
  ),

  textTheme: GoogleFonts.getTextTheme('Afacad'),
  
);
