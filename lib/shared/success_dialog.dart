import 'package:ac_app/theme.dart';
import 'package:ac_app/shared/styled_text.dart';
import 'package:ac_app/shared/styled_button.dart';
import 'package:flutter/material.dart';

/// Shows a centered success dialog with a check icon
/// Reusable widget that matches the app's style and theme
Future<void> showSuccessDialog(BuildContext context, String message) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.increaseColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: AppColors.increaseColor,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            
            // Message
            SecondaryText(
              message,
              fontSize: 14,
              color: AppColors.titleColor,
            ),
            const SizedBox(height: 32),
            
            // OK Button
            SizedBox(
              width: double.infinity,
              child: StyledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

