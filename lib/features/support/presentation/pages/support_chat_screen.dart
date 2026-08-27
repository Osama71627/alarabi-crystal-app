import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/chat_thread_view.dart';

/// شاشة الدعم المباشر للعميل — محادثة واحدة ثابتة مع الإدارة
class SupportChatScreen extends StatelessWidget {
  const SupportChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.supportChat)),
      body: user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(AppStrings.loginRequired),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.push(AppRoutes.login),
                    child: Text(AppStrings.login),
                  ),
                ],
              ),
            )
          : ChatThreadView(
              chatUid: user.uid,
              currentUserId: user.uid,
              isAdmin: false,
              customerName: user.name,
            ),
    );
  }
}
