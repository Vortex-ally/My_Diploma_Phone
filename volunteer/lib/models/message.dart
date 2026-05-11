class Message {
  final int id;
  final int senderId;
  final int recipientId;
  final String content;
  final DateTime createdAt;
  final bool isRead;
  final bool isMine;

  const Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.createdAt,
    required this.isRead,
    required this.isMine,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      senderId: json['sender_id'] as int,
      recipientId: json['recipient_id'] as int,
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isRead: json['is_read'] as bool? ?? false,
      isMine: json['is_mine'] as bool? ?? false,
    );
  }
}

class ChatPreview {
  final int id;
  final String username;
  final String name;
  final String role;
  final String? lastContent;
  final DateTime? lastAt;
  final bool lastFromMe;
  final int unreadCount;

  const ChatPreview({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
    this.lastContent,
    this.lastAt,
    this.lastFromMe = false,
    this.unreadCount = 0,
  });

  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';

  factory ChatPreview.fromJson(Map<String, dynamic> json) {
    final last = json['last_message'] as Map<String, dynamic>?;
    return ChatPreview(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      lastContent: last?['content'] as String?,
      lastAt: last != null && last['created_at'] != null
          ? DateTime.tryParse(last['created_at'] as String)
          : null,
      lastFromMe: last?['is_mine'] as bool? ?? false,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}

class ChatPartner {
  final int id;
  final String username;
  final String name;
  final String role;

  const ChatPartner({
    required this.id,
    required this.username,
    required this.name,
    required this.role,
  });

  factory ChatPartner.fromJson(Map<String, dynamic> json) {
    return ChatPartner(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
    );
  }
}
