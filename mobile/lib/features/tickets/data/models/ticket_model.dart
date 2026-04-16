import 'message_model.dart';

class TicketModel {
  final int id;
  final String ticketNumber;
  final String status;
  final String priority;
  final String? guardianName;
  final String? guardianPhone;
  final String? studentName;
  final String? lastMessage;
  final int unreadCount;
  final String? assignedToName;
  final int? assignedToId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? slaDeadline;
  final List<String> tags;
  final List<MessageModel> messages;

  const TicketModel({
    required this.id,
    required this.ticketNumber,
    required this.status,
    required this.priority,
    this.guardianName,
    this.guardianPhone,
    this.studentName,
    this.lastMessage,
    this.unreadCount = 0,
    this.assignedToName,
    this.assignedToId,
    required this.createdAt,
    required this.updatedAt,
    this.slaDeadline,
    this.tags = const [],
    this.messages = const [],
  });

  factory TicketModel.fromJson(Map<String, dynamic> json) {
    return TicketModel(
      id: json['id'],
      ticketNumber: json['ticket_number'] ?? '#${json['id']}',
      status: json['status'] ?? 'open',
      priority: json['priority'] ?? 'normal',
      guardianName: json['guardian']?['name'] ?? json['guardian_name'],
      guardianPhone: json['guardian']?['phone'] ?? json['guardian_phone'],
      studentName: json['student']?['name'] ?? json['student_name'],
      lastMessage: json['last_message']?['body'] ?? json['last_message_preview'],
      unreadCount: json['unread_count'] ?? 0,
      assignedToName: json['assigned_to']?['name'] ?? json['assigned_to_name'],
      assignedToId: json['assigned_to']?['id'] ?? json['assigned_to_id'],
      createdAt: DateTime.parse(json['created_at']).toLocal(),
      updatedAt: DateTime.parse(json['updated_at']).toLocal(),
      slaDeadline: json['sla_deadline'] != null
          ? DateTime.parse(json['sla_deadline']).toLocal()
          : null,
      tags: json['tags'] != null
          ? (json['tags'] as List).map((t) => t is String ? t : t['name'].toString()).toList()
          : [],
      messages: json['messages'] != null
          ? (json['messages'] as List).map((m) => MessageModel.fromJson(m)).toList()
          : [],
    );
  }

  String get statusDisplay {
    switch (status) {
      case 'open': return 'مفتوح';
      case 'assigned': return 'معين';
      case 'pending': return 'معلق';
      case 'resolved': return 'محلول';
      case 'closed': return 'مغلق';
      case 'escalated': return 'متصاعد';
      default: return status;
    }
  }

  String get priorityDisplay {
    switch (priority) {
      case 'low': return 'منخفض';
      case 'normal': return 'عادي';
      case 'high': return 'عالي';
      case 'urgent': return 'عاجل';
      default: return priority;
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return 'منذ ${(diff.inDays / 7).floor()} أسبوع';
  }

  Duration? get slaRemaining {
    if (slaDeadline == null) return null;
    final remaining = slaDeadline!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isSlaBreached => slaRemaining == Duration.zero;
}
