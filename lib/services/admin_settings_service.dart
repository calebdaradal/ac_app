import 'package:supabase_flutter/supabase_flutter.dart';

class AdminSettingsService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get the annual withdraw date from admin_settings table
  /// Returns null if no date is set
  static Future<DateTime?> getAnnualWithdrawDate() async {
    try {
      final response = await _supabase
          .from('admin_settings')
          .select('annual_withdraw_date')
          .maybeSingle();

      if (response == null || response['annual_withdraw_date'] == null) {
        return null;
      }

      final dateString = response['annual_withdraw_date'] as String;
      return DateTime.parse(dateString);
    } catch (e) {
      print('[AdminSettingsService] Error fetching annual withdraw date: $e');
      return null;
    }
  }

  /// Update the annual withdraw date in admin_settings table
  /// Since admin_settings table has no primary key, we delete all rows and insert a new one
  static Future<void> updateAnnualWithdrawDate(DateTime date) async {
    try {
      final dateString = date.toIso8601String().split('T')[0]; // Format as YYYY-MM-DD

      // Delete all existing rows - use a filter that matches any row
      // Since the table only has one column, we can delete rows where annual_withdraw_date is not null
      try {
        final existingRows = await _supabase
            .from('admin_settings')
            .select('annual_withdraw_date');
        
        if (existingRows.isNotEmpty) {
          // Delete all rows - Supabase requires a filter, so we use a condition that matches all
          await _supabase
              .from('admin_settings')
              .delete()
              .not('annual_withdraw_date', 'is', null);
        }
      } catch (deleteError) {
        // If delete fails, continue to insert (might be first time setting the date)
        print('[AdminSettingsService] Note: Could not delete existing rows: $deleteError');
      }

      // Insert new row with the updated date
      await _supabase.from('admin_settings').insert({
        'annual_withdraw_date': dateString,
      });

      print('[AdminSettingsService] Annual withdraw date updated to: $dateString');
    } catch (e) {
      print('[AdminSettingsService] Error updating annual withdraw date: $e');
      rethrow;
    }
  }

  /// Check if withdrawals are currently allowed based on annual withdraw date
  /// Returns true if current date >= annual_withdraw_date, or if no date is set
  static Future<bool> isWithdrawalAllowed() async {
    final annualDate = await getAnnualWithdrawDate();
    if (annualDate == null) {
      // If no date is set, allow withdrawals
      return true;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final withdrawDate = DateTime(annualDate.year, annualDate.month, annualDate.day);

    return today.isAfter(withdrawDate) || today.isAtSameMomentAs(withdrawDate);
  }
}

