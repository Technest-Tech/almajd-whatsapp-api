class ReminderModel {
  final int id;
  final String type; // session_reminder, guardian_notification, custom
  final int? classSessionId;
  final String recipientPhone;
  final String? recipientName;
  final String? templateName;
  final String? messageBody;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final String status; // pending, sent, failed, cancelled
  final String? failureReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReminderModel({
    required this.id,
    required this.type,
    this.classSessionId,
    required this.recipientPhone,
    this.recipientName,
    this.templateName,
    this.messageBody,
    this.scheduledAt,
    this.sentAt,
    this.status = 'pending',
    this.failureReason,
    this.createdAt,
    this.updatedAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    return ReminderModel(
      id: json['id'],
      type: json['type'] ?? 'custom',
      classSessionId: json['class_session_id'],
      recipientPhone: json['recipient_phone'] ?? '',
      recipientName: json['recipient_name'],
      templateName: json['template_name'],
      messageBody: json['message_body'],
      scheduledAt: json['scheduled_at'] != null ? DateTime.tryParse(json['scheduled_at']) : null,
      sentAt: json['sent_at'] != null ? DateTime.tryParse(json['sent_at']) : null,
      status: json['status'] ?? 'pending',
      failureReason: json['failure_reason'],
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'class_session_id': classSessionId,
    'recipient_phone': recipientPhone,
    'recipient_name': recipientName,
    'template_name': templateName,
    'message_body': messageBody,
    'scheduled_at': scheduledAt?.toIso8601String(),
  };

  String get typeDisplay {
    switch (type) {
      case 'session_reminder':
        return 'تذكير بالحصة';
      case 'guardian_notification':
        return 'إشعار ولي الأمر';
      case 'custom':
        return 'رسالة مخصصة';
      default:
        return type;
    }
  }

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'معلّق';
      case 'sent':
        return 'تم الإرسال';
      case 'failed':
        return 'فشل';
      case 'cancelled':
        return 'ملغى';
      default:
        return status;
    }
  }

  String get scheduledAtDisplay {
    if (scheduledAt == null) return '';
    return '${scheduledAt!.day}/${scheduledAt!.month}/${scheduledAt!.year} ${scheduledAt!.hour.toString().padLeft(2, '0')}:${scheduledAt!.minute.toString().padLeft(2, '0')}';
  }
}
