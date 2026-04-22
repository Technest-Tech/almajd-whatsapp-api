import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/repositories/auth_repository.dart';

/// Real API implementation of AuthRepository
class AuthRepositoryImpl implements AuthRepository {
  UserModel? _currentUser;
  final ApiService _apiService = ApiService();

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _apiService.post('/login', data: {
        'email': email,
        'password': password,
      });

      final data = response.data;
      final token = data['token'] as String;
      final userData = data['user'] as Map<String, dynamic>;

      debugPrint('🔍 Login: Received user data: ${jsonEncode(userData)}');

      // Store token
      await StorageService.saveToken(token);
      debugPrint('💾 Login: Token saved to storage');
      
      // Store user data as JSON string
      final userJson = jsonEncode(userData);
      await StorageService.saveUserData(userJson);
      debugPrint('💾 Login: User data saved to storage: ${userData['email']}');

      // Set token in API service for future requests
      _apiService.setAuthToken(token);

      // Parse user from response
      try {
        _currentUser = UserModel.fromJson(userData);
        debugPrint('✅ Login: User parsed successfully - ${_currentUser!.email}, role: ${_currentUser!.role.name}');
        return _currentUser!;
      } catch (e, stackTrace) {
        debugPrint('❌ Login: Failed to parse user data: $e');
        debugPrint('❌ Stack trace: $stackTrace');
        debugPrint('❌ User data: ${jsonEncode(userData)}');
        rethrow;
      }
    } catch (e) {
      // Fallback to mock for development if API is not available
      UserModel? mockUser;
      
      if (email.isEmpty && password.isEmpty) {
        mockUser = UserModel.mockAdmin;
      } else if (email == 'admin@almajd.com' && password == 'admin123') {
        mockUser = UserModel.mockAdmin;
      } else if (email == 'teacher@almajd.com' && password == 'teacher123') {
        mockUser = UserModel.mockTeacher;
      } else if (email == 'student@almajd.com' && password == 'student123') {
        mockUser = UserModel.mockStudent;
      }
      
      if (mockUser != null) {
        // Save mock user data and token to shared preferences
        _currentUser = mockUser;
        
        // Save a mock token (for consistency)
        await StorageService.saveToken('mock_token_${mockUser.id}');
        debugPrint('💾 Mock Login: Token saved to storage');
        
        // Save user data as JSON
        final userJson = jsonEncode(mockUser.toJson());
        await StorageService.saveUserData(userJson);
        debugPrint('💾 Mock Login: User data saved to storage: ${mockUser.email}');
        
        // Set token in API service
        _apiService.setAuthToken('mock_token_${mockUser.id}');
        
        return mockUser;
      }
      
      throw Exception('Invalid credentials: ${e.toString()}');
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Try to call logout API
      await _apiService.post('/logout');
    } catch (e) {
      // Ignore errors on logout
    } finally {
      // Clear local storage
      await StorageService.clearAll();
      _apiService.clearAuthToken();
      _currentUser = null;
    }
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    // First, try to get user from stored preferences
    try {
      final userDataJson = await StorageService.getUserData();
      final token = await StorageService.getToken();
      
      debugPrint('🔍 getCurrentUser: Checking stored data...');
      debugPrint('🔍 Token exists: ${token != null}');
      debugPrint('🔍 User data exists: ${userDataJson != null && userDataJson.isNotEmpty}');
      
      if (userDataJson != null && userDataJson.isNotEmpty && token != null) {
        final userData = jsonDecode(userDataJson) as Map<String, dynamic>;
        _currentUser = UserModel.fromJson(userData);
        
        // Also restore the token if available
        _apiService.setAuthToken(token);
        
        debugPrint('✅ getCurrentUser: Successfully loaded user from storage: ${_currentUser?.email}');
        return _currentUser;
      } else {
        debugPrint('⚠️ getCurrentUser: No stored data found');
      }
    } catch (e) {
      // If parsing stored user data fails, try API
      debugPrint('❌ getCurrentUser: Failed to parse stored user data: $e');
    }

    // Try to get user from API
    try {
      final token = await StorageService.getToken();
      if (token != null && !token.startsWith('mock_token_')) {
        _apiService.setAuthToken(token);
        final response = await _apiService.get('/user');
        _currentUser = UserModel.fromJson(response.data);
        
        // Save the updated user data
        final userJson = jsonEncode(_currentUser!.toJson());
        await StorageService.saveUserData(userJson);
        
        return _currentUser;
      }
    } catch (e) {
      // If API call fails but we have a mock token, try to load from storage again
      final token = await StorageService.getToken();
      if (token != null && token.startsWith('mock_token_')) {
        // Try to reload from storage if _currentUser is null
        if (_currentUser == null) {
          try {
            final userDataJson = await StorageService.getUserData();
            if (userDataJson != null && userDataJson.isNotEmpty) {
              final userData = jsonDecode(userDataJson) as Map<String, dynamic>;
              _currentUser = UserModel.fromJson(userData);
              return _currentUser;
            }
          } catch (e) {
            debugPrint('Failed to reload user from storage: $e');
          }
        } else {
          return _currentUser;
        }
      }
      
      // Token might be invalid, clear it
      await StorageService.clearAll();
      _apiService.clearAuthToken();
    }

    return null;
  }
}
