import 'package:dio/dio.dart';
import '../../../../core/api/api_client.dart';
import 'models/template_model.dart';

class TemplateRepository {
  final ApiClient apiClient;

  TemplateRepository({required this.apiClient});

  // ── List all templates (admin) ────────────────────────────────────────────

  Future<List<TemplateModel>> getTemplates({
    String? status,
    String? search,
    int perPage = 50,
  }) async {
    final params = <String, dynamic>{'per_page': perPage};
    if (status != null) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await apiClient.dio.get(
      '/templates',
      queryParameters: params,
    );
    final List data = response.data['data'];
    return data.map((j) => TemplateModel.fromJson(j)).toList();
  }

  // ── Approved only (for agent chat picker) ────────────────────────────────

  Future<List<TemplateModel>> getApprovedTemplates() async {
    final response = await apiClient.dio.get('/templates/approved');
    final List data = response.data['data'];
    return data.map((j) => TemplateModel.fromJson(j)).toList();
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<TemplateModel> createTemplate({
    required String name,
    required String bodyTemplate,
    String language = 'ar',
    String category = 'UTILITY',
    String? headerText,
    String? footerText,
    List<String> variablesSchema = const [],
  }) async {
    final response = await apiClient.dio.post('/templates', data: {
      'name':              name,
      'body_template':     bodyTemplate,
      'language':          language,
      'category':          category,
      if (headerText != null) 'header_text': headerText,
      if (footerText != null) 'footer_text': footerText,
      'variables_schema':  variablesSchema,
    });
    return TemplateModel.fromJson(response.data['data']);
  }

  // ── Submit for Meta approval ──────────────────────────────────────────────

  Future<TemplateModel> submitTemplate(int templateId) async {
    final response = await apiClient.dio.post('/templates/$templateId/submit');
    return TemplateModel.fromJson(response.data['data']);
  }

  // ── Sync approval statuses from Twilio ───────────────────────────────────

  Future<int> syncTemplates() async {
    final response = await apiClient.dio.post('/templates/sync');
    return response.data['data']['updated'] as int;
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteTemplate(int templateId) async {
    await apiClient.dio.delete('/templates/$templateId');
  }

  // ── Send template message via ticket ─────────────────────────────────────

  Future<Map<String, dynamic>> sendTemplate({
    required int ticketId,
    required int templateId,
    List<String> variables = const [],
  }) async {
    final response = await apiClient.dio.post(
      '/tickets/$ticketId/send-template',
      data: {
        'template_id': templateId,
        'variables':   variables,
      },
    );
    return Map<String, dynamic>.from(response.data['data']);
  }
}
