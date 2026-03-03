import '../../../core/api/api_client.dart';

class AdminRepository {
  final ApiClient apiClient;

  AdminRepository({required this.apiClient});

  // ── Users ──

  Future<List<Map<String, dynamic>>> getUsers({
    String? role,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'per_page': perPage};
    if (role != null && role != 'all') params['role'] = role;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await apiClient.dio.get('/admin/users', queryParameters: params);
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<Map<String, dynamic>> getUser(int id) async {
    final response = await apiClient.dio.get('/admin/users/$id');
    return Map<String, dynamic>.from(response.data['data']);
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post('/admin/users', data: data);
    return Map<String, dynamic>.from(response.data['data']);
  }

  Future<Map<String, dynamic>> updateUser(int id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put('/admin/users/$id', data: data);
    return Map<String, dynamic>.from(response.data['data']);
  }

  Future<void> deleteUser(int id) async {
    await apiClient.dio.delete('/admin/users/$id');
  }

  // ── Analytics ──

  Future<Map<String, dynamic>> getAnalytics({String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await apiClient.dio.get('/admin/analytics', queryParameters: params);
    return Map<String, dynamic>.from(response.data['data']);
  }

  // ── Audit Log ──

  Future<List<Map<String, dynamic>>> getAuditLog({
    int? ticketId,
    int? userId,
    String? action,
    String? from,
    String? to,
    int perPage = 50,
  }) async {
    final params = <String, dynamic>{'per_page': perPage};
    if (ticketId != null) params['ticket_id'] = ticketId;
    if (userId != null) params['user_id'] = userId;
    if (action != null) params['action'] = action;
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;

    final response = await apiClient.dio.get('/admin/audit-log', queryParameters: params);
    return List<Map<String, dynamic>>.from(response.data['data']);
  }
}
