import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local storage (tokens, user data, etc.)
class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  /// Save authentication token
  static Future<void> saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_tokenKey, token);
      if (success) {
        debugPrint('✅ StorageService: Token saved successfully');
      } else {
        debugPrint('❌ StorageService: Failed to save token');
      }
    } catch (e) {
      debugPrint('❌ StorageService: Error saving token: $e');
      rethrow;
    }
  }

  /// Get authentication token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Clear authentication token
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Save user data
  static Future<void> saveUserData(String userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_userKey, userData);
      if (success) {
        debugPrint('✅ StorageService: User data saved successfully');
      } else {
        debugPrint('❌ StorageService: Failed to save user data');
      }
    } catch (e) {
      debugPrint('❌ StorageService: Error saving user data: $e');
      rethrow;
    }
  }

  /// Get user data
  static Future<String?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey);
  }

  /// Clear user data
  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
  }

  /// Clear all stored data
  static Future<void> clearAll() async {
    await clearToken();
    await clearUserData();
  }
}

