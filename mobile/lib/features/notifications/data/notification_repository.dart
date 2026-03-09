import '../../../core/api/api_client.dart';
import 'models/notification_model.dart';

class NotificationRepository {
  final ApiClient apiClient;

  NotificationRepository({required this.apiClient});

  Future<List<NotificationItem>> getNotifications({int page = 1, int perPage = 30}) async {
    final response = await apiClient.dio.get(
      '/notifications',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final List data = response.data['data'] ?? [];
    return data.map((j) => NotificationItem.fromJson(j)).toList();
  }

  Future<int> getUnreadCount() async {
    final response = await apiClient.dio.get('/notifications/unread-count');
    return response.data['data']['unread_count'] as int? ?? 0;
  }

  Future<void> markAsRead(int id) async {
    await apiClient.dio.post('/notifications/$id/read');
  }

  Future<void> markAllAsRead() async {
    await apiClient.dio.post('/notifications/read-all');
  }
}
