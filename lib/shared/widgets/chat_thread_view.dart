import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

/// عرض محادثة دعم واحدة (فقاعات رسائل + حقل إرسال) — يُستخدم من شاشة
/// العميل وشاشة الإدارة معاً بنفس المنطق
class ChatThreadView extends StatefulWidget {
  const ChatThreadView({
    super.key,
    required this.chatUid,
    required this.currentUserId,
    required this.isAdmin,
    required this.customerName,
  });

  /// معرّف صاحب المحادثة (العميل) — نفس معرّف المستخدم للعميل نفسه، أو
  /// معرّف العميل المستهدف عند فتح الإدارة لمحادثته
  final String chatUid;
  final String currentUserId;
  final bool isAdmin;
  final String customerName;

  @override
  State<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<ChatThreadView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isAdmin) {
        ChatService.instance.markReadByAdmin(widget.chatUid);
      } else {
        ChatService.instance.markReadByCustomer(widget.chatUid);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ChatService.instance.sendMessage(
        uid: widget.chatUid,
        senderId: widget.currentUserId,
        isAdmin: widget.isAdmin,
        customerName: widget.customerName,
        text: text,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: ChatService.instance.watchMessages(widget.chatUid),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? const <ChatMessage>[];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      AppStrings.chatWelcome,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                );
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                }
              });
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: AppStrings.typeMessage,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isAdmin = message.isFromAdmin;
    final time = message.createdAt;
    return Align(
      alignment: isAdmin ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isAdmin
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : AppColors.secondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: isAdmin ? null : Colors.white,
              ),
            ),
            if (time != null) ...[
              const SizedBox(height: 4),
              Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 10,
                  color: isAdmin
                      ? Theme.of(context).colorScheme.outline
                      : Colors.white70,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
