import '../../../../core/utils/api_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/models/user_model.dart';
import 'dart:convert';

class LessonSettingsService {
  static final ApiService _apiService = ApiService();
  static Map<String, bool>? _cachedSettings;
  static DateTime? _lastFetch;

  /// Get lesson settings from API
  static Future<Map<String, bool>> getLessonSettings({bool forceRefresh = false}) async {
    // Cache settings for 30 seconds (reduced for faster updates)
    if (!forceRefresh && 
        _cachedSettings != null && 
        _lastFetch != null && 
        DateTime.now().difference(_lastFetch!).inSeconds < 30) {
      return _cachedSettings!;
    }

    try {
      final token = await StorageService.getToken();
      if (token != null) {
        _apiService.setAuthToken(token);
      }
      final response = await _apiService.get('/lesson-settings');
      final data = response.data['data'] as Map<String, dynamic>;
      _cachedSettings = {
        'teachers_can_edit_lessons': data['teachers_can_edit_lessons'] as bool? ?? false,
        'teachers_can_delete_lessons': data['teachers_can_delete_lessons'] as bool? ?? false,
        'teachers_can_add_past_lessons': data['teachers_can_add_past_lessons'] as bool? ?? false,
      };
      _lastFetch = DateTime.now();
      return _cachedSettings!;
    } catch (e) {
      // Return default values on error (disabled by default)
      return {
        'teachers_can_edit_lessons': false,
        'teachers_can_delete_lessons': false,
        'teachers_can_add_past_lessons': false,
      };
    }
  }

  /// Check if current user is a teacher
  static Future<bool> isTeacher() async {
    try {
      final userDataJson = await StorageService.getUserData();
      if (userDataJson != null && userDataJson.isNotEmpty) {
        final userData = jsonDecode(userDataJson) as Map<String, dynamic>;
        final user = UserModel.fromJson(userData);
        return user.role.name == 'teacher';
      }
    } catch (e) {
      // Default to false on error
    }
    return false;
  }

  /// Clear cache (call when settings are updated)
  static void clearCache() {
    _cachedSettings = null;
    _lastFetch = null;
  }
}
