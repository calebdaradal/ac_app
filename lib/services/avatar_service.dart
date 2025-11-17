import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling avatar uploads to Supabase storage
class AvatarService {
  static const String _bucketName = 'avatar';
  
  /// Upload avatar image to Supabase storage
  /// Returns the public URL of the uploaded avatar
  /// Throws exception if upload fails
  /// Deletes old avatars before uploading new one to ensure only one avatar per user
  Future<String> uploadAvatar(File imageFile, String userId) async {
    try {
      final client = Supabase.instance.client;
      
      // Delete old avatars first to ensure only one avatar per user
      print('[AvatarService] Deleting old avatars for user: $userId');
      await deleteAvatar(userId);
      
      // Use consistent filename: avatar.png (always replaces the same file)
      final filePath = '$userId/avatar.png';
      
      // Verify the file exists and get its size
      final fileSize = await imageFile.length();
      print('[AvatarService] Uploading file: ${imageFile.path}');
      print('[AvatarService] File size: $fileSize bytes');
      
      // Determine content type - always PNG since we process to PNG
      const contentType = 'image/png';
      
      // Upload to Supabase storage (upsert will replace if exists)
      await client.storage
          .from(_bucketName)
          .upload(
            filePath,
            imageFile,
            fileOptions: FileOptions(
              upsert: true,
              contentType: contentType,
            ),
          );
      
      print('[AvatarService] File uploaded successfully to: $filePath');
      
      // Verify file exists and list remaining files
      try {
        final files = await client.storage
            .from(_bucketName)
            .list(path: userId);
        print('[AvatarService] Files in user folder after upload: ${files.map((f) => f.name).toList()}');
        print('[AvatarService] Total files for user: ${files.length} (should be 1)');
      } catch (e) {
        print('[AvatarService] Warning: Could not list files: $e');
      }
      
      // Get public URL
      String publicUrl;
      try {
        // Generate public URL
        publicUrl = client.storage
            .from(_bucketName)
            .getPublicUrl(filePath);
        
        print('[AvatarService] Generated public URL: $publicUrl');
        print('[AvatarService] File path: $filePath');
        print('[AvatarService] Bucket: $_bucketName');
        
        // Verify the URL format matches Supabase's expected format
        // Expected: https://[project-ref].supabase.co/storage/v1/object/public/[bucket]/[path]
        if (!publicUrl.contains('/storage/v1/object/public/')) {
          print('[AvatarService] WARNING: URL format might be incorrect');
        }
      } catch (e) {
        print('[AvatarService] Error generating public URL: $e');
        // Fallback: construct URL manually
        final storageUrl = client.storage.from(_bucketName).getPublicUrl(filePath);
        publicUrl = storageUrl;
        print('[AvatarService] Using fallback URL: $publicUrl');
      }
      
      // Note: If you get HTTP 400 errors, make sure:
      // 1. The bucket is set to "Public" in Supabase Dashboard → Storage → Edit bucket
      // 2. The RLS policies allow public read access (Policy 4 in rls_policies_storage_avatar.sql)
      // 3. The URL matches what Supabase shows in "Get URL" button
      
      return publicUrl;
    } catch (e) {
      throw Exception('Failed to upload avatar: $e');
    }
  }
  
  /// Delete avatar from Supabase storage
  /// Returns true if successful
  Future<bool> deleteAvatar(String userId) async {
    try {
      final client = Supabase.instance.client;
      
      // List all files for this user
      final files = await client.storage
          .from(_bucketName)
          .list(path: userId);
      
      // Delete all files for this user
      if (files.isNotEmpty) {
        final filePaths = files.map((file) => '$userId/${file.name}').toList();
        await client.storage
            .from(_bucketName)
            .remove(filePaths);
      }
      
      return true;
    } catch (e) {
      print('Error deleting avatar: $e');
      return false;
    }
  }
  
  /// Update avatar URL in user profile
  Future<void> updateProfileAvatarUrl(String userId, String avatarUrl) async {
    try {
      final client = Supabase.instance.client;
      
      await client
          .from('profiles')
          .update({'avatar_url': avatarUrl})
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to update profile avatar URL: $e');
    }
  }
}

