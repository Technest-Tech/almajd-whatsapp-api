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
  final String deliveryStatus; // 'sent' | 'delivered' | 'read' | 'failed' | 'sending'
  final bool isInternal; // internal note visible only to staff
  final DateTime createdAt;

  // Reply-to fields for quoted replies
  final int? replyToId;
  final String? replyToBody;
  final String? replyToSender;
  final String? replyToType;

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
    this.replyToId,
    this.replyToBody,
    this.replyToSender,
    this.replyToType,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['created_at'] ?? json['timestamp'];
    return MessageModel(
      id: json['id'],
      ticketId: json['ticket_id'],
      body: json['content'] ?? json['body'] ?? '',
      direction: json['direction'] ?? 'inbound',
      type: json['message_type'] ?? json['type'] ?? 'text',
      senderName: json['sender_name'] ?? json['sender']?['name'],
      mediaUrl: json['media_url'],
      mediaType: json['media_type'],
      deliveryStatus: json['delivery_status'] ?? 'delivered',
      isInternal: json['is_internal'] ?? false,
      createdAt: rawDate != null ? DateTime.parse(rawDate) : DateTime.now(),
      replyToId: json['reply_to_id'],
      replyToBody: json['reply_to_body'],
      replyToSender: json['reply_to_sender'],
      replyToType: json['reply_to_type'],
    );
  }

  bool get isInbound => direction == 'inbound';
  bool get isOutbound => direction == 'outbound';
  bool get isSystem => type == 'system';

  /// Returns true if message body contains only emoji characters (≤6 chars).
  bool get isEmojiOnly {
    if (body.isEmpty || body.length > 12) return false;
    // Match common emoji patterns (Unicode emoji ranges)
    final emojiRegex = RegExp(
      r'^[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}'
      r'\u{1F1E0}-\u{1F1FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}'
      r'\u{FE00}-\u{FE0F}\u{1F900}-\u{1F9FF}\u{200D}\u{20E3}'
      r'\u{E0020}-\u{E007F}\s]+$',
      unicode: true,
    );
    return emojiRegex.hasMatch(body);
  }

  String get timeFormatted {
    final hour = createdAt.hour;
    final minute = createdAt.minute.toString().padLeft(2, '0');
    final isPm = hour >= 12;
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = isPm ? 'م' : 'ص';
    return '$h12:$minute $suffix';
  }

  /// Copy with override for reply fields
  MessageModel copyWith({
    int? id,
    int? ticketId,
    String? body,
    String? direction,
    String? type,
    String? senderName,
    String? mediaUrl,
    String? mediaType,
    String? deliveryStatus,
    bool? isInternal,
    DateTime? createdAt,
    int? replyToId,
    String? replyToBody,
    String? replyToSender,
    String? replyToType,
  }) {
    return MessageModel(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      body: body ?? this.body,
      direction: direction ?? this.direction,
      type: type ?? this.type,
      senderName: senderName ?? this.senderName,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      isInternal: isInternal ?? this.isInternal,
      createdAt: createdAt ?? this.createdAt,
      replyToId: replyToId ?? this.replyToId,
      replyToBody: replyToBody ?? this.replyToBody,
      replyToSender: replyToSender ?? this.replyToSender,
      replyToType: replyToType ?? this.replyToType,
    );
  }
}
