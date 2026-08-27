import 'package:flutter/material.dart';

import '../../../../core/widgets/network_image_widget.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/app_user.dart';
import '../../domain/repositories/admin_repository.dart';
import '../widgets/admin_widgets.dart';

/// إدارة المستخدمين
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<AppUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<AdminRepository>().getAllUsers();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppUser>>(
      future: _future,
      builder: (context, snapshot) {
        final users = snapshot.data ?? const <AppUser>[];
        final admins = users.where((u) => u.role == UserRole.admin).length;
        final customers = users.length - admins;

        return Column(
          children: [
            AdminPageHeader(
              icon: Icons.group_outlined,
              title: AppStrings.adminUsers,
              subtitle: snapshot.connectionState == ConnectionState.waiting
                  ? null
                  : '${users.length} ${AppStrings.totalUsers} • $customers ${AppStrings.customer} • $admins ${AppStrings.admin}',
            ),
            const Divider(height: 1),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError
                      ? Center(child: Text(AppStrings.errorGeneric))
                      : users.isEmpty
                          ? const AdminEmptyState(
                              icon: Icons.group_outlined,
                              title: AppStrings.noData,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: users.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, i) => _UserTile(user: users[i]),
                            ),
            ),
          ],
        );
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final created = user.createdAt;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: user.avatar != null && user.avatar!.isNotEmpty
            ? ClipOval(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: NetworkImageWidget(imageUrl: user.avatar!),
                ),
              )
            : CircleAvatar(
                backgroundColor: user.isAdmin
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  user.isAdmin ? Icons.shield_outlined : Icons.person_outline,
                  color: user.isAdmin
                      ? const Color(0xFF8B5CF6)
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user.name.isEmpty ? AppStrings.guest : user.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (user.isAdmin) ...[
              const SizedBox(width: 6),
              const StatusPill(
                label: 'مدير',
                color: Color(0xFF8B5CF6),
                icon: Icons.verified,
                dense: true,
              ),
            ],
          ],
        ),
        subtitle: Text(
          user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          created != null
              ? '${created.day}/${created.month}/${created.year}'
              : '',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}
