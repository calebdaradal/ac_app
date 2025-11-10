import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static Color primaryColor = const Color.fromRGBO(255, 117, 31, 1);
  static Color secondaryColor = const Color.fromRGBO(255, 247, 243, 1);
  static Color tertiaryColor = const Color.fromRGBO(25, 170, 180, 1);
  static Color titleColor = const Color.fromRGBO(34, 43, 69, 1);
  static Color secondaryTextColor = const Color.fromRGBO(143, 155, 179, 1);
  static Color increaseColor = const Color.fromRGBO(6, 186, 45, 1);
  static Color decreaseColor = const Color.fromRGBO(251, 104, 104, 1);
  static Color pendingColor = const Color.fromRGBO(219, 185, 33, 1);
}

ThemeData primaryTheme = ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primaryColor,
  ),

  textTheme: GoogleFonts.getTextTheme('Afacad'),
  
);
