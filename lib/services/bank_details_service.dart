import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_profile_service.dart';

class BankDetailsService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch bank details for the current user (returns first one found)
  static Future<BankDetails?> getBankDetails() async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    print('[BankDetails] Fetching bank details for user: $uid');

    final response = await _supabase
        .from('bankdetails')
        .select('id, bank_name, acaccount_number, location, account_name, short_code')
        .eq('user_uid', uid)
        .maybeSingle();

    if (response == null) {
      print('[BankDetails] No bank details found');
      return null;
    }

    print('[BankDetails] Bank details found: $response');

    return BankDetails(
      id: response['id'] as int,
      bankName: response['bank_name'] as String,
      accountNumber: response['acaccount_number'].toString(),
      location: response['location'] as String,
      accountName: response['account_name'] as String,
      shortCode: response['short_code']?.toString(),
    );
  }

  /// Fetch all bank details for the current user
  static Future<List<BankDetails>> getAllBankDetails() async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    print('[BankDetails] Fetching all bank details for user: $uid');

    final response = await _supabase
        .from('bankdetails')
        .select('id, bank_name, acaccount_number, location, account_name, short_code')
        .eq('user_uid', uid)
        .order('id', ascending: true);

    print('[BankDetails] Found ${response.length} bank details');

    return (response as List).map((item) {
      return BankDetails(
        id: item['id'] as int,
        bankName: item['bank_name'] as String,
        accountNumber: item['acaccount_number'].toString(),
        location: item['location'] as String,
        accountName: item['account_name'] as String,
        shortCode: item['short_code']?.toString(),
      );
    }).toList();
  }

  /// Update or create bank details for the current user
  static Future<void> saveBankDetails({
    required String bankName,
    required String accountNumber,
    required String location,
    required String accountName,
    String? shortCode,
  }) async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    // Check if bank details already exist
    final existing = await _supabase
        .from('bankdetails')
        .select('id')
        .eq('user_uid', uid)
        .maybeSingle();

    final data = {
      'bank_name': bankName,
      'acaccount_number': int.parse(accountNumber),
      'location': location,
      'account_name': accountName,
      'short_code': shortCode != null && shortCode.isNotEmpty ? int.tryParse(shortCode) : null,
    };

    if (existing != null) {
      // Update existing
      await _supabase
          .from('bankdetails')
          .update(data)
          .eq('user_uid', uid);
      print('[BankDetails] Bank details updated');
    } else {
      // Create new
      await _supabase.from('bankdetails').insert({
        'user_uid': uid,
        ...data,
      });
      print('[BankDetails] Bank details created');
    }
  }

  /// Add a new bank detail for the current user
  static Future<void> addBankDetail({
    required String bankName,
    required String accountNumber,
    required String location,
    required String accountName,
    String? shortCode,
  }) async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    final data = {
      'user_uid': uid,
      'bank_name': bankName,
      'acaccount_number': int.parse(accountNumber),
      'location': location,
      'account_name': accountName,
      'short_code': shortCode != null && shortCode.isNotEmpty ? int.tryParse(shortCode) : null,
    };

    await _supabase.from('bankdetails').insert(data);
    print('[BankDetails] New bank detail created');
  }

  /// Update an existing bank detail
  static Future<void> updateBankDetail({
    required int id,
    required String bankName,
    required String accountNumber,
    required String location,
    required String accountName,
    String? shortCode,
  }) async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    final data = {
      'bank_name': bankName,
      'acaccount_number': int.parse(accountNumber),
      'location': location,
      'account_name': accountName,
      'short_code': shortCode != null && shortCode.isNotEmpty ? int.tryParse(shortCode) : null,
    };

    await _supabase
        .from('bankdetails')
        .update(data)
        .eq('id', id)
        .eq('user_uid', uid); // Ensure user can only update their own

    print('[BankDetails] Bank detail updated (id: $id)');
  }

  /// Delete a bank detail
  static Future<void> deleteBankDetail(int id) async {
    final uid = UserProfileService().profile?.uid;
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    await _supabase
        .from('bankdetails')
        .delete()
        .eq('id', id)
        .eq('user_uid', uid); // Ensure user can only delete their own

    print('[BankDetails] Bank detail deleted (id: $id)');
  }

  /// Fetch all bank details for admin users
  static Future<List<BankDetails>> getAdminBankDetails() async {
    print('[BankDetails] Fetching admin bank details');

    try {
      // First, get all admin user IDs from profiles table
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('is_admin', true);

      if (profilesResponse.isEmpty) {
        print('[BankDetails] No admin users found');
        return [];
      }

      final adminUids = (profilesResponse as List)
          .map((profile) => profile['id'] as String)
          .toList();

      print('[BankDetails] Found ${adminUids.length} admin users: $adminUids');

      // Now get bank details for these admin users
      final bankDetailsResponse = await _supabase
          .from('bankdetails')
          .select('id, bank_name, acaccount_number, location, account_name, short_code')
          .inFilter('user_uid', adminUids)
          .order('id', ascending: true);

      print('[BankDetails] Found ${bankDetailsResponse.length} admin bank details');

      return (bankDetailsResponse as List).map((item) {
        return BankDetails(
          id: item['id'] as int,
          bankName: item['bank_name'] as String,
          accountNumber: item['acaccount_number'].toString(),
          location: item['location'] as String,
          accountName: item['account_name'] as String,
          shortCode: item['short_code']?.toString(),
        );
      }).toList();
    } catch (e) {
      print('[BankDetails] Error fetching admin bank details: $e');
      rethrow;
    }
  }

  /// Check if user has complete bank details
  static Future<bool> hasCompleteBankDetails() async {
    final details = await getBankDetails();
    return details != null &&
        details.bankName.isNotEmpty &&
        details.accountNumber.isNotEmpty &&
        details.location.isNotEmpty &&
        details.accountName.isNotEmpty;
  }
}

/// Bank details model
class BankDetails {
  final int id;
  final String bankName;
  final String accountNumber;
  final String location;
  final String accountName;
  final String? shortCode;

  BankDetails({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.location,
    required this.accountName,
    this.shortCode,
  });
}

