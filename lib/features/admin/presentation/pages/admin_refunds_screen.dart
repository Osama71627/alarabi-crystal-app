import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/refund_request.dart';
import '../../../../shared/services/currency_formatter.dart';
import '../../../../shared/services/refund_service.dart';
import '../widgets/admin_widgets.dart';

/// إدارة طلبات الاسترداد: مراجعة + موافقة/رفض
class AdminRefundsScreen extends StatefulWidget {
  const AdminRefundsScreen({super.key});

  @override
  State<AdminRefundsScreen> createState() => _AdminRefundsScreenState();
}

class _AdminRefundsScreenState extends State<AdminRefundsScreen> {
  RefundStatus? _filter = RefundStatus.pending;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RefundRequest>>(
      stream: RefundService.instance.watchAllRequests(),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <RefundRequest>[];
        final requests =
            _filter == null ? all : all.where((r) => r.status == _filter).toList();
        final pendingCount = all.where((r) => r.status == RefundStatus.pending).length;

        return Column(
          children: [
            AdminPageHeader(
              icon: Icons.assignment_return_outlined,
              title: AppStrings.myRefundRequests,
              subtitle: '${all.length} طلب'
                  '${pendingCount > 0 ? ' • $pendingCount قيد الانتظار' : ''}',
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip(null, AppStrings.all),
                  _chip(RefundStatus.pending, AppStrings.refundPending),
                  _chip(RefundStatus.approved, AppStrings.refundApproved),
                  _chip(RefundStatus.rejected, AppStrings.refundRejected),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : requests.isEmpty
                      ? const AdminEmptyState(
                          icon: Icons.assignment_return_outlined,
                          title: AppStrings.noRefundRequests,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: requests.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _RefundCard(request: requests[index]),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(RefundStatus? status, String label) {
    final selected = _filter == status;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = status),
      ),
    );
  }
}

class _RefundCard extends StatefulWidget {
  const _RefundCard({required this.request});

  final RefundRequest request;

  @override
  State<_RefundCard> createState() => _RefundCardState();
}

class _RefundCardState extends State<_RefundCard> {
  bool _processing = false;

  Future<void> _resolve(bool approve) async {
    setState(() => _processing = true);
    try {
      await RefundService.instance.resolve(
        requestId: widget.request.id,
        approve: approve,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorGeneric)),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final (label, color) = switch (request.status) {
      RefundStatus.pending => (AppStrings.refundPending, AppColors.warning),
      RefundStatus.approved => (AppStrings.refundApproved, AppColors.success),
      RefundStatus.rejected => (AppStrings.refundRejected, Theme.of(context).colorScheme.error),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'طلب #${request.orderId.substring(0, request.orderId.length > 8 ? 8 : request.orderId.length)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusPill(label: label, color: color, dense: true),
              ],
            ),
            const SizedBox(height: 6),
            Text(request.reason, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(
              CurrencyFormatter.formatClean(request.amount),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (request.status == RefundStatus.pending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _processing ? null : () => _resolve(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      child: Text(AppStrings.rejectRefund),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _processing ? null : () => _resolve(true),
                      child: _processing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(AppStrings.approveRefund),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
