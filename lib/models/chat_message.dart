class ChatMessage {
  final String id;
  final String threadId;
  final String senderType; // 'user', 'aphrodite', 'salon', 'system'
  final String? senderId;
  final String contentType; // 'text', 'image', 'tryon_result', 'booking_card', 'system'
  final String? textContent;
  final String? mediaUrl;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderType,
    this.senderId,
    this.contentType = 'text',
    this.textContent,
    this.mediaUrl,
    this.metadata = const {},
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      threadId: json['thread_id'] as String,
      senderType: json['sender_type'] as String,
      senderId: json['sender_id'] as String?,
      contentType: (json['content_type'] as String?) ?? 'text',
      textContent: json['text_content'] as String?,
      mediaUrl: json['media_url'] as String?,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'thread_id': threadId,
      'sender_type': senderType,
      'sender_id': senderId,
      'content_type': contentType,
      'text_content': textContent,
      'media_url': mediaUrl,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Whether this message was sent by the user
  bool get isFromUser => senderType == 'user';

  /// Whether this is an Aphrodite response
  bool get isFromAphrodite => senderType == 'aphrodite';

  /// Whether this message contains an image
  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  /// Whether this is a try-on result
  bool get isTryOnResult => contentType == 'tryon_result';
}
