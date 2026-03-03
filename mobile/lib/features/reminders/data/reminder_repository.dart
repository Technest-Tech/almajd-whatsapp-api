import '../../../core/api/api_client.dart';
import 'models/reminder_model.dart';

class ReminderRepository {
  final ApiClient apiClient;

  ReminderRepository({required this.apiClient});

  Future<List<ReminderModel>> getReminders({
    String? status,
    String? type,
    String? from,
    String? to,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (status != null && status != 'all') params['status'] = status;
    if (type != null && type != 'all') params['type'] = type;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await apiClient.dio.get('/reminders', queryParameters: params);
    final List data = response.data['data'];
    return data.map((j) => ReminderModel.fromJson(j)).toList();
  }

  Future<ReminderModel> createReminder(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post('/reminders', data: data);
    return ReminderModel.fromJson(response.data['data']);
  }

  Future<ReminderModel> cancelReminder(int id) async {
    final response = await apiClient.dio.put('/reminders/$id/cancel');
    return ReminderModel.fromJson(response.data['data']);
  }

  Future<int> bulkCreate(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post('/reminders/bulk', data: data);
    return response.data['data']['count'] ?? 0;
  }
}
