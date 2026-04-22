import '../../../../core/utils/api_service.dart';

abstract class SettingsRemoteDataSource {
  Future<Map<String, bool>> getPaymentSettings();
  Future<Map<String, bool>> updatePaymentSettings({
    required bool paypalEnabled,
    required bool anubpayEnabled,
  });
  Future<Map<String, bool>> getLessonSettings();
  Future<Map<String, bool>> updateLessonSettings({
    required bool teachersCanEditLessons,
    required bool teachersCanDeleteLessons,
    required bool teachersCanAddPastLessons,
  });
}

class SettingsRemoteDataSourceImpl implements SettingsRemoteDataSource {
  final ApiService apiService;

  SettingsRemoteDataSourceImpl(this.apiService);

  /// Safely convert a value to boolean, handling bool, int, and string types
  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  @override
  Future<Map<String, bool>> getPaymentSettings() async {
    final response = await apiService.get('/payment-settings');
    final data = response.data['data'] as Map<String, dynamic>;
    return {
      'paypal_enabled': _toBool(data['paypal_enabled']),
      'anubpay_enabled': _toBool(data['anubpay_enabled']),
    };
  }

  @override
  Future<Map<String, bool>> updatePaymentSettings({
    required bool paypalEnabled,
    required bool anubpayEnabled,
  }) async {
    final response = await apiService.put(
      '/payment-settings',
      data: {
        'paypal_enabled': paypalEnabled,
        'anubpay_enabled': anubpayEnabled,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return {
      'paypal_enabled': _toBool(data['paypal_enabled']),
      'anubpay_enabled': _toBool(data['anubpay_enabled']),
    };
  }

  @override
  Future<Map<String, bool>> getLessonSettings() async {
    final response = await apiService.get('/lesson-settings');
    final data = response.data['data'] as Map<String, dynamic>;
    return {
      'teachers_can_edit_lessons': _toBool(data['teachers_can_edit_lessons']),
      'teachers_can_delete_lessons': _toBool(data['teachers_can_delete_lessons']),
      'teachers_can_add_past_lessons': _toBool(data['teachers_can_add_past_lessons']),
    };
  }

  @override
  Future<Map<String, bool>> updateLessonSettings({
    required bool teachersCanEditLessons,
    required bool teachersCanDeleteLessons,
    required bool teachersCanAddPastLessons,
  }) async {
    final response = await apiService.put(
      '/lesson-settings',
      data: {
        'teachers_can_edit_lessons': teachersCanEditLessons,
        'teachers_can_delete_lessons': teachersCanDeleteLessons,
        'teachers_can_add_past_lessons': teachersCanAddPastLessons,
      },
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return {
      'teachers_can_edit_lessons': _toBool(data['teachers_can_edit_lessons']),
      'teachers_can_delete_lessons': _toBool(data['teachers_can_delete_lessons']),
      'teachers_can_add_past_lessons': _toBool(data['teachers_can_add_past_lessons']),
    };
  }
}
