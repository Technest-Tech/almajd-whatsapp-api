import '../../../core/api/api_client.dart';
import 'models/ticket_model.dart';

class TicketRepository {
  final ApiClient apiClient;

  TicketRepository({required this.apiClient});

  Future<List<TicketModel>> getTickets({
    String? status,
    String? priority,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };
    if (status != null && status != 'all') params['status'] = status;
    if (priority != null) params['priority'] = priority;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await apiClient.dio.get('/tickets', queryParameters: params);
    final List data = response.data['data'];
    return data.map((j) => TicketModel.fromJson(j)).toList();
  }

  Future<TicketModel> getTicket(int id) async {
    final response = await apiClient.dio.get('/tickets/$id');
    return TicketModel.fromJson(response.data['data']);
  }

  Future<Map<String, dynamic>> getStats() async {
    final response = await apiClient.dio.get('/tickets/stats');
    return Map<String, dynamic>.from(response.data['data']);
  }

  Future<void> assignTicket(int ticketId, int userId) async {
    await apiClient.dio.put('/tickets/$ticketId/assign', data: {
      'assigned_to': userId,
    });
  }

  Future<void> updateStatus(int ticketId, String status) async {
    await apiClient.dio.put('/tickets/$ticketId/status', data: {
      'status': status,
    });
  }

  Future<void> escalateTicket(int ticketId, {String? reason}) async {
    await apiClient.dio.post('/tickets/$ticketId/escalate', data: {
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> replyToTicket(int ticketId, String body) async {
    await apiClient.dio.post('/tickets/$ticketId/reply', data: {
      'body': body,
    });
  }
}
