/// Represents a single message in a ticket conversation.
class MessageModel {
  final int id;
  final int ticketId;
  final String body;
  final String direction; // 'inbound' | 'outbound'
  final String type; // 'text' | 'image' | 'audio' | 'document' | 'system'
  final String? senderName;
  final String? mediaUrl;
  final String? mediaType;
  final String deliveryStatus; // 'sent' | 'delivered' | 'read' | 'failed'
  final bool isInternal; // internal note visible only to staff
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.ticketId,
    required this.body,
    required this.direction,
    this.type = 'text',
    this.senderName,
    this.mediaUrl,
    this.mediaType,
    this.deliveryStatus = 'delivered',
    this.isInternal = false,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'],
      ticketId: json['ticket_id'],
      body: json['body'] ?? '',
      direction: json['direction'] ?? 'inbound',
      type: json['type'] ?? 'text',
      senderName: json['sender_name'] ?? json['sender']?['name'],
      mediaUrl: json['media_url'],
      mediaType: json['media_type'],
      deliveryStatus: json['delivery_status'] ?? 'delivered',
      isInternal: json['is_internal'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isInbound => direction == 'inbound';
  bool get isOutbound => direction == 'outbound';
  bool get isSystem => type == 'system';

  String get timeFormatted {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
