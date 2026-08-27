import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/chat_message.dart';

/// خدمة الدعم المباشر — محادثة واحدة لكل عميل مع الإدارة، محفوظة في
/// `supportChats/{uid}/messages`، مع مستند ملخّص علوي `supportChats/{uid}`
/// لعرض قائمة المحادثات بلوحة الإدارة دون قراءة كل الرسائل
class ChatService {
  ChatService._internal();
  static final ChatService instance = ChatService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chats =>
      _firestore.collection('supportChats');

  /// بث رسائل محادثة عميل معيّن (الأقدم أولاً لعرض طبيعي بالدردشة)
  Stream<List<ChatMessage>> watchMessages(String uid) {
    return _chats
        .doc(uid)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// حدّ أعلى مقصود (المرحلة 13 — M6): صندوق دعم الإدارة كان يحمّل كل
  /// محادثات كل العملاء تاريخياً بلا سقف. سخي بما يكفي لصندوق نشِط فعلياً.
  static const int _allChatsLimit = 200;

  /// بث كل المحادثات (للوحة الإدارة)، الأحدث نشاطاً أولاً
  Stream<List<ChatSummary>> watchAllChats() {
    return _chats
        .orderBy('lastMessageAt', descending: true)
        .limit(_allChatsLimit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatSummary.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// إرسال رسالة — يحدّد الدور والمُرسل من الجلسة الحالية، وليس من العميل
  Future<void> sendMessage({
    required String uid,
    required String senderId,
    required bool isAdmin,
    required String customerName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final now = DateTime.now();
    final message = ChatMessage(
      id: '',
      senderId: senderId,
      senderRole: isAdmin ? 'admin' : 'customer',
      text: trimmed,
      createdAt: now,
    );
    await _chats.doc(uid).collection('messages').add(message.toMap());
    await _chats.doc(uid).set({
      'customerName': customerName,
      'lastMessage': trimmed,
      'lastMessageAt': now.toIso8601String(),
      // إشعار غير مقروء للطرف الآخر فقط
      'unreadByAdmin': !isAdmin,
      'unreadByCustomer': isAdmin,
    }, SetOptions(merge: true));
  }

  /// تحديد محادثة كمقروءة من طرف الإدارة
  Future<void> markReadByAdmin(String uid) {
    return _chats.doc(uid).set({'unreadByAdmin': false}, SetOptions(merge: true));
  }

  /// تحديد محادثة كمقروءة من طرف العميل
  Future<void> markReadByCustomer(String uid) {
    return _chats.doc(uid).set({'unreadByCustomer': false}, SetOptions(merge: true));
  }
}
