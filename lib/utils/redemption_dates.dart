/// Utility class for checking redemption dates
/// Redemption dates are specific dates when withdrawals don't incur the 5% penalty fee
class RedemptionDates {
  /// Check if a given date is a redemption date
  /// Redemption dates are:
  /// - March 30-31
  /// - June 29-30
  /// - September 29-30
  /// - December 30-31
  static bool isRedemptionDate(DateTime date) {
    final month = date.month;
    final day = date.day;
    
    // Check redemption dates
    switch (month) {
      case 3: // March
        return day == 30 || day == 31;
      case 6: // June
        return day == 29 || day == 30;
      case 9: // September
        return day == 29 || day == 30;
      case 12: // December
        return day == 30 || day == 31;
      default:
        return false;
    }
  }
  
  /// Get all redemption dates for a given year (for display purposes)
  static List<DateTime> getRedemptionDatesForYear(int year) {
    return [
      DateTime(year, 3, 30),
      DateTime(year, 3, 31),
      DateTime(year, 6, 29),
      DateTime(year, 6, 30),
      DateTime(year, 9, 29),
      DateTime(year, 9, 30),
      DateTime(year, 12, 30),
      DateTime(year, 12, 31),
    ];
  }
}

