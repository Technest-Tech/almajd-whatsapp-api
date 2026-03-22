import 'dart:convert';

class TemplateModel {
  final int id;
  final String name;
  final String language;
  final String category;
  final String bodyTemplate;
  final String? headerType;
  final String? headerText;
  final String? footerText;
  final String status; // draft / pending / approved / rejected
  final String? contentSid;
  final List<String> variablesSchema;
  final String? rejectionReason;

  const TemplateModel({
    required this.id,
    required this.name,
    required this.language,
    required this.category,
    required this.bodyTemplate,
    this.headerType,
    this.headerText,
    this.footerText,
    required this.status,
    this.contentSid,
    required this.variablesSchema,
    this.rejectionReason,
  });

  bool get isApproved => status == 'approved';
  bool get isPending  => status == 'pending';
  bool get isDraft    => status == 'draft';
  bool get isRejected => status == 'rejected';

  /// Resolve body by substituting {{1}}, {{2}} … with provided values.
  String resolveBody(List<String> values) {
    String result = bodyTemplate;
    for (int i = 0; i < values.length; i++) {
      result = result.replaceAll('{{${i + 1}}}', values[i]);
    }
    return result;
  }

  factory TemplateModel.fromJson(Map<String, dynamic> json) => TemplateModel(
        id:               json['id'] as int,
        name:             json['name'] as String,
        language:         json['language'] as String? ?? 'ar',
        category:         json['category'] as String? ?? 'UTILITY',
        bodyTemplate:     json['body_template'] as String,
        headerType:       json['header_type'] as String?,
        headerText:       json['header_text'] as String?,
        footerText:       json['footer_text'] as String?,
        status:           json['status'] as String,
        contentSid:       json['content_sid'] as String?,
        variablesSchema:  _parseVariablesSchema(json['variables_schema']),
        rejectionReason:  json['rejection_reason'] as String?,
      );

  static List<String> _parseVariablesSchema(dynamic schema) {
    if (schema == null) return [];
    if (schema is String) {
      if (schema.isEmpty) return [];
      try {
        final decoded = jsonDecode(schema);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
        if (decoded is Map) return decoded.values.map((v) => v.toString()).toList();
      } catch (_) {}
      return [];
    }
    if (schema is List) {
      return schema.map((e) => e.toString()).toList();
    }
    if (schema is Map) {
      return schema.values.map((v) => v.toString()).toList();
    }
    return [];
  }

  Map<String, dynamic> toJson() => {
        'id':              id,
        'name':            name,
        'language':        language,
        'category':        category,
        'body_template':   bodyTemplate,
        'header_type':     headerType,
        'header_text':     headerText,
        'footer_text':     footerText,
        'status':          status,
        'content_sid':     contentSid,
        'variables_schema': variablesSchema,
        'rejection_reason': rejectionReason,
      };
}
