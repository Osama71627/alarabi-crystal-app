/// رسالة بمحادثة الدعم المباشر
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    this.createdAt,
    this.read = false,
  });

  final String id;
  final String senderId;

  /// 'customer' أو 'admin'
  final String senderRole;
  final String text;
  final DateTime? createdAt;
  final bool read;

  bool get isFromAdmin => senderRole == 'admin';

  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    return ChatMessage(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      senderRole: map['senderRole'] as String? ?? 'customer',
      text: map['text'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      read: map['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderRole': senderRole,
      'text': text,
      'createdAt': createdAt?.toIso8601String(),
      'read': read,
    };
  }
}

/// ملخّص محادثة (للوحة تحكم الإدارة — قائمة كل المحادثات)
class ChatSummary {
  const ChatSummary({
    required this.uid,
    required this.customerName,
    this.lastMessage = '',
    this.lastMessageAt,
    this.unreadByAdmin = false,
  });

  final String uid;
  final String customerName;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final bool unreadByAdmin;

  factory ChatSummary.fromMap(Map<String, dynamic> map, String uid) {
    return ChatSummary(
      uid: uid,
      customerName: map['customerName'] as String? ?? '',
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageAt: map['lastMessageAt'] != null
          ? DateTime.tryParse(map['lastMessageAt'].toString())
          : null,
      unreadByAdmin: map['unreadByAdmin'] as bool? ?? false,
    );
  }
}
