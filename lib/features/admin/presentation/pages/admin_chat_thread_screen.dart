import 'package:flutter/material.dart';

import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/chat_thread_view.dart';

/// محادثة الإدارة مع عميل معيّن
class AdminChatThreadScreen extends StatelessWidget {
  const AdminChatThreadScreen({
    super.key,
    required this.customerUid,
    required this.customerName,
  });

  final String customerUid;
  final String customerName;

  @override
  Widget build(BuildContext context) {
    final adminUid = AuthService.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(customerName.isEmpty ? AppStrings.guest : customerName),
      ),
      body: ChatThreadView(
        chatUid: customerUid,
        currentUserId: adminUid,
        isAdmin: true,
        customerName: customerName,
      ),
    );
  }
}
