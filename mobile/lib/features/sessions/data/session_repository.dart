import '../../../core/api/api_client.dart';
import 'models/session_model.dart';

class SessionRepository {
  final ApiClient apiClient;

  SessionRepository({required this.apiClient});

  Future<List<SessionModel>> getSessions({
    String? date,
    String? from,
    String? to,
    String? status,
    int? teacherId,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (date != null) params['date'] = date;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (status != null && status != 'all') params['status'] = status;
    if (teacherId != null) params['teacher_id'] = teacherId;

    final response = await apiClient.dio.get('/sessions', queryParameters: params);
    final List data = response.data['data'];
    return data.map((j) => SessionModel.fromJson(j)).toList();
  }

  Future<SessionModel> getSession(int id) async {
    final response = await apiClient.dio.get('/sessions/$id');
    return SessionModel.fromJson(response.data['data']);
  }

  Future<SessionModel> updateStatus(int id, {required String status, String? reason}) async {
    final data = <String, dynamic>{'status': status};
    if (reason != null) data['cancellation_reason'] = reason;
    final response = await apiClient.dio.put('/sessions/$id/status', data: data);
    return SessionModel.fromJson(response.data['data']);
  }

  Future<int> getPendingCount() async {
    try {
      final response = await apiClient.dio.get('/sessions/pending-count');
      return response.data['data']['count'] as int;
    } catch (_) {
      return 0;
    }
  }
}
