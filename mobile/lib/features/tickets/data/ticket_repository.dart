import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import 'models/message_model.dart';
import 'models/ticket_model.dart';

class TicketRepository {
  final ApiClient apiClient;

  TicketRepository({required this.apiClient});

  Future<List<TicketModel>> getTickets({
    String? type,
    String? priority,
    String? search,
    int page = 1,
    int perPage = 20,
  }) async {
    final params = <String, dynamic>{'page': page, 'per_page': perPage};
    if (type != null && type != 'all') params['type'] = type;
    if (priority != null) params['priority'] = priority;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await apiClient.dio.get(
      '/tickets',
      queryParameters: params,
    );
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
    await apiClient.dio.put(
      '/tickets/$ticketId/assign',
      data: {'assigned_to': userId},
    );
  }

  Future<void> updateStatus(int ticketId, String status) async {
    await apiClient.dio.put(
      '/tickets/$ticketId/status',
      data: {'status': status},
    );
  }

  Future<void> escalateTicket(int ticketId, {String? reason}) async {
    await apiClient.dio.post(
      '/tickets/$ticketId/escalate',
      data: {if (reason != null) 'reason': reason},
    );
  }

  Future<MessageModel> replyToTicket(
    int ticketId,
    String content, {
    String? mediaUrl,
    int? replyToMessageId,
  }) async {
    final response = await apiClient.dio.post(
      '/tickets/$ticketId/reply',
      data: {
        'content': content,
        if (mediaUrl != null) 'media_url': mediaUrl,
        if (replyToMessageId != null)
          'reply_to_message_id': replyToMessageId.toString(),
      },
    );
    return MessageModel.fromJson(response.data['data']);
  }

  Future<Map<String, dynamic>> uploadTicketMedia(
    int ticketId,
    File file,
  ) async {
    final fileName = file.path.split('/').last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    final response = await apiClient.dio.post(
      '/tickets/$ticketId/upload',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return Map<String, dynamic>.from(response.data['data']);
  }

  /// Delete a ticket permanently.
  Future<void> deleteTicket(int ticketId) async {
    // We use ResponseType.plain because Laravel might return an empty 2xx or simple string
    // which causes Dio to throw a JSON parse exception on some Flutter versions.
    await apiClient.dio.delete(
      '/tickets/$ticketId',
      options: Options(responseType: ResponseType.plain),
    );
  }

  /// Mark a ticket as read to reset unread counts
  Future<void> markAsRead(int ticketId) async {
    await apiClient.dio.post('/tickets/$ticketId/read');
  }

  /// Get paginated messages for a ticket (newest first, reversed for display)
  Future<Map<String, dynamic>> getMessages(int ticketId, {int page = 1, int perPage = 30}) async {
    final response = await apiClient.dio.get(
      '/tickets/$ticketId/messages',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final List data = response.data['data'];
    final messages = data.map((j) => MessageModel.fromJson(j)).toList();
    final meta = response.data['meta'] ?? {};
    return {
      'messages': messages,
      'current_page': meta['current_page'] ?? page,
      'last_page': meta['last_page'] ?? 1,
    };
  }

  /// Lightweight unread count (for bottom nav badge)
  Future<int> getUnreadCount() async {
    final response = await apiClient.dio.get('/tickets/unread-count');
    return response.data['data']['unread_count'] as int? ?? 0;
  }

  /// Create (or find) a ticket for a student — returns the ticket data including `id`.
  Future<int> createTicketForStudent(int studentId) async {
    final response = await apiClient.dio.post(
      '/tickets/create-for-student',
      data: {'student_id': studentId},
    );
    return response.data['data']['id'] as int;
  }

  /// Create (or find) a ticket for a teacher by whatsapp number — returns ticket id.
  Future<int> createTicketForTeacher(String whatsappNumber) async {
    final response = await apiClient.dio.post(
      '/tickets/create-for-contact',
      data: {'phone': whatsappNumber},
    );
    return response.data['data']['id'] as int;
  }
}
