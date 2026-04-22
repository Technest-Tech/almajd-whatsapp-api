import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminAuthService {
  static const String _tokenKey = 'adminToken';
  static const String _baseUrl = 'https://almajdmeet.org';
  static const String _adminEmail = 'admin@newmeet.com';
  static const String _adminPassword = 'admin123';

  // Auto-login and get token (will login if token doesn't exist)
  static Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      
      // If token exists, return it
      if (token != null && token.isNotEmpty) {
        return token;
      }
      
      // Otherwise, auto-login
      print('🔐 AdminAuth: Auto-logging in...');
      final loginResult = await login(_adminEmail, _adminPassword);
      
      if (loginResult['success'] == true) {
        return loginResult['token'] as String?;
      }
      
      return null;
    } catch (e) {
      print('❌ AdminAuth: Get token error: $e');
      return null;
    }
  }

  // Login with email and password
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      print('🔐 AdminAuth: Attempting login for: $email');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      print('🔐 AdminAuth: Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String;

        // Store token
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);

        print('✅ AdminAuth: Login successful');
        return {
          'success': true,
          'token': token,
        };
      } else {
        final error = json.decode(response.body) as Map<String, dynamic>;
        print('❌ AdminAuth: Login failed - ${error['error']}');
        return {
          'success': false,
          'error': error['error'] ?? 'Login failed',
        };
      }
    } catch (e) {
      print('❌ AdminAuth: Login error: $e');
      return {
        'success': false,
        'error': 'Network error: ${e.toString()}',
      };
    }
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('❌ AdminAuth: Authentication check error: $e');
      return false;
    }
  }

  // Clear token (for logout if needed in future)
  static Future<void> clearToken() async {
    try {
      print('🔐 AdminAuth: Clearing token');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      print('✅ AdminAuth: Token cleared');
    } catch (e) {
      print('❌ AdminAuth: Clear token error: $e');
    }
  }
}

