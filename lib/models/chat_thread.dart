class ChatThread {
  final String id;
  final String userId;
  final String contactType; // 'aphrodite', 'salon', 'user'
  final String? contactId;
  final String? contactName;
  final String? openaiThreadId;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool pinned;
  final DateTime createdAt;

  const ChatThread({
    required this.id,
    required this.userId,
    required this.contactType,
    this.contactId,
    this.contactName,
    this.openaiThreadId,
    this.lastMessageText,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.pinned = false,
    required this.createdAt,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      contactType: json['contact_type'] as String,
      contactId: json['contact_id'] as String?,
      contactName: json['contact_name'] as String?,
      openaiThreadId: json['openai_thread_id'] as String?,
      lastMessageText: json['last_message_text'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: (json['unread_count'] as int?) ?? 0,
      pinned: (json['pinned'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'contact_type': contactType,
      'contact_id': contactId,
      'contact_name': contactName,
      'openai_thread_id': openaiThreadId,
      'last_message_text': lastMessageText,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'unread_count': unreadCount,
      'pinned': pinned,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Display name for the contact
  String get displayName {
    switch (contactType) {
      case 'aphrodite':
        return 'Afrodita';
      case 'support':
        return 'Soporte BeautyCita';
      default:
        return contactName ?? contactId ?? 'Chat';
    }
  }

  /// Whether this is an Aphrodite AI thread
  bool get isAphrodite => contactType == 'aphrodite';

  /// Whether this is a support thread
  bool get isSupport => contactType == 'support';

  ChatThread copyWith({
    String? lastMessageText,
    DateTime? lastMessageAt,
    int? unreadCount,
    String? openaiThreadId,
  }) {
    return ChatThread(
      id: id,
      userId: userId,
      contactType: contactType,
      contactId: contactId,
      contactName: contactName,
      openaiThreadId: openaiThreadId ?? this.openaiThreadId,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      pinned: pinned,
      createdAt: createdAt,
    );
  }
}
