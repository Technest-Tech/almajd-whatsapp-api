class NotificationItem {
  final int id;
  final String type; // message, class_reminder, reminder_log
  final String title;
  final String? body;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  int? get ticketId => data?['ticket_id'] as int?;
  int? get sessionId => data?['session_id'] as int?;
  String? get guardianName => data?['guardian_name'] as String?;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'],
      type: json['type'] ?? 'message',
      title: json['title'] ?? '',
      body: json['body'],
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data']) : null,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at']) : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
