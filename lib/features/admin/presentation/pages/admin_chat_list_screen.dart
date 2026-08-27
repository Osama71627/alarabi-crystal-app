import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/chat_message.dart';
import '../../../../shared/services/chat_service.dart';
import '../widgets/admin_widgets.dart';
import 'admin_chat_thread_screen.dart';

/// قائمة محادثات الدعم المباشر (للإدارة)
class AdminChatListScreen extends StatelessWidget {
  const AdminChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ChatSummary>>(
      stream: ChatService.instance.watchAllChats(),
      builder: (context, snapshot) {
        final chats = snapshot.data ?? const <ChatSummary>[];
        final unreadCount = chats.where((c) => c.unreadByAdmin).length;
        return Column(
          children: [
            AdminPageHeader(
              icon: Icons.support_agent_outlined,
              title: AppStrings.supportChat,
              subtitle: '${chats.length} محادثة'
                  '${unreadCount > 0 ? ' • $unreadCount غير مقروءة' : ''}',
            ),
            const Divider(height: 1),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : chats.isEmpty
                      ? const AdminEmptyState(
                          icon: Icons.support_agent_outlined,
                          title: AppStrings.noData,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: chats.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final chat = chats[index];
                            return _ChatSummaryTile(chat: chat);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _ChatSummaryTile extends StatelessWidget {
  const _ChatSummaryTile({required this.chat});

  final ChatSummary chat;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminChatThreadScreen(
              customerUid: chat.uid,
              customerName: chat.customerName,
            ),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.person_outline, color: AppColors.primary),
        ),
        title: Text(
          chat.customerName.isEmpty ? AppStrings.guest : chat.customerName,
          style: TextStyle(
            fontWeight: chat.unreadByAdmin ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          chat.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: chat.unreadByAdmin
            ? const StatusPill(label: 'جديد', color: AppColors.secondary, dense: true)
            : null,
      ),
    );
  }
}
