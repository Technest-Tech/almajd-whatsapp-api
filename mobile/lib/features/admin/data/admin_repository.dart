import '../../../core/api/api_client.dart';

class AdminRepository {
  final ApiClient apiClient;

  AdminRepository({required this.apiClient});

  // ── Supervisors ──

  Future<List<Map<String, dynamic>>> getSupervisors({
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'per_page': perPage};
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await apiClient.dio.get('/admin/supervisors', queryParameters: params);
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<Map<String, dynamic>> getSupervisor(int id) async {
    final response = await apiClient.dio.get('/admin/supervisors/$id');
    return Map<String, dynamic>.from(response.data['data']);
  }

  Future<Map<String, dynamic>> createSupervisor(Map<String, dynamic> data) async {
    final response = await apiClient.dio.post('/admin/supervisors', data: data);
    return Map<String, dynamic>.from(response.data['data']);
  }

  Future<Map<String, dynamic>> updateSupervisor(int id, Map<String, dynamic> data) async {
    final response = await apiClient.dio.put('/admin/supervisors/$id', data: data);
    return Map<String, dynamic>.from(response.data['data']);
  }

  Future<void> deleteSupervisor(int id) async {
    await apiClient.dio.delete('/admin/supervisors/$id');
  }

  Future<Map<String, dynamic>> getSupervisorPerformance(int id, {String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    
    final response = await apiClient.dio.get('/admin/supervisors/$id/performance', queryParameters: params);
    return Map<String, dynamic>.from(response.data['data']);
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
