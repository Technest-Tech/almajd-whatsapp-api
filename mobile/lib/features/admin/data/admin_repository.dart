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

  Future<List<Map<String, dynamic>>> getShifts(int supervisorId) async {
    final response = await apiClient.dio.get('/admin/supervisors/$supervisorId/shifts');
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<List<Map<String, dynamic>>> updateShifts(
    int supervisorId,
    List<Map<String, dynamic>> shifts,
  ) async {
    final response = await apiClient.dio.put(
      '/admin/supervisors/$supervisorId/shifts',
      data: {'shifts': shifts},
    );
    return List<Map<String, dynamic>>.from(response.data['data']);
  }

  Future<Map<String, dynamic>> getSupervisorPerformance(int id, {String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    
    final response = await apiClient.dio.get('/admin/supervisors/$id/performance', queryParameters: params);
    return Map<String, dynamic>.from(response.data['data']);
  }

  Future<List<Map<String, dynamic>>> getAggregatedSupervisorsPerformance({String? from, String? to}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    
    final response = await apiClient.dio.get('/admin/supervisors/performance', queryParameters: params);
    return List<Map<String, dynamic>>.from(response.data['data']);
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

  // ── Active WhatsApp Number (Wasender session switch) ──

  /// Returns `{active: 'primary'|'old', options: [{session, number, configured}]}`.
  Future<Map<String, dynamic>> getWhatsAppNumber() async {
    final response = await apiClient.dio.get('/admin/whatsapp-number');
    return Map<String, dynamic>.from(response.data['data']);
  }

  /// Switches the active number. [session] is 'primary' or 'old'.
  Future<Map<String, dynamic>> setWhatsAppNumber(String session) async {
    final response = await apiClient.dio.put('/admin/whatsapp-number', data: {'session': session});
    return Map<String, dynamic>.from(response.data['data']);
  }

  // ── WhatsApp Group routing (teacher↔student pair → shared group) ──

  /// Saved mappings for display. Returns `{active_number, groups: [...]}` where
  /// each group is `{id, teacher_id, student_id, group_jid, group_name,
  /// whatsapp_number, is_active, teacher: {...}, student: {...}}`.
  Future<Map<String, dynamic>> getWhatsAppGroups() async {
    final response = await apiClient.dio.get('/admin/whatsapp-groups');
    return Map<String, dynamic>.from(response.data['data']);
  }

  /// Groups the CURRENTLY-ACTIVE number belongs to, each with an auto-suggested
  /// teacher/student. Returns `{active_number, groups: [{group_jid, group_name,
  /// participants, already_linked, suggested_teacher, suggested_student}]}`.
  Future<Map<String, dynamic>> discoverWhatsAppGroups() async {
    final response = await apiClient.dio.get('/admin/whatsapp-groups/discover');
    return Map<String, dynamic>.from(response.data['data']);
  }

  /// Link (or re-link) a teacher↔student pair to a group JID.
  Future<Map<String, dynamic>> linkWhatsAppGroup({
    required int teacherId,
    required int studentId,
    required String groupJid,
    String? groupName,
  }) async {
    final response = await apiClient.dio.post('/admin/whatsapp-groups', data: {
      'teacher_id': teacherId,
      'student_id': studentId,
      'group_jid': groupJid,
      if (groupName != null) 'group_name': groupName,
    });
    return Map<String, dynamic>.from(response.data['data']);
  }

  Future<void> unlinkWhatsAppGroup(int id) async {
    await apiClient.dio.delete('/admin/whatsapp-groups/$id');
  }
}
