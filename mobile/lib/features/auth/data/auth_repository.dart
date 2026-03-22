import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/fcm_service.dart';
import 'models/user_model.dart';

class AuthRepository {
  final ApiClient apiClient;
  final FlutterSecureStorage storage;

  AuthRepository({required this.apiClient, required this.storage});

  Future<UserModel> login({
    required String email,
    required String password,
    String? deviceId,
    String? deviceName,
  }) async {
    final fcmToken = FcmService.token ?? await FcmService.refreshToken();
    // Must match what ApiClient uses during token refresh.
    final effectiveDeviceId = deviceId ?? 'flutter_mobile_client';
    final response = await apiClient.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
      'device_id': effectiveDeviceId,
      'device_name': deviceName ?? 'Flutter App',
      if (fcmToken != null) 'fcm_token': fcmToken,
    });

    final data = response.data['data'];
    await storage.write(key: 'access_token', value: data['access_token']);
    await storage.write(key: 'refresh_token', value: data['refresh_token']);
    await storage.write(key: 'device_id', value: effectiveDeviceId);

    return UserModel.fromJson(data['user']);
  }

  Future<UserModel> getProfile() async {
    final response = await apiClient.dio.get('/auth/me');
    return UserModel.fromJson(response.data['data']);
  }

  Future<void> logout() async {
    try {
      await apiClient.dio.post('/auth/logout');
    } catch (_) {
      // Silent fail — clear tokens anyway
    }
    await storage.deleteAll();
  }

  Future<void> updateAvailability(String availability) async {
    await apiClient.dio.put('/auth/me/availability', data: {
      'availability': availability,
    });
  }

  Future<bool> hasValidToken() async {
    final token = await storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }
}
