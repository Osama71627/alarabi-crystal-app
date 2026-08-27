import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/coupon.dart';
import '../../../../shared/services/coupon_admin_service.dart';
import '../../../../shared/services/currency_formatter.dart';
import '../widgets/admin_widgets.dart';

/// إدارة كوبونات الخصم: إنشاء/تعديل/حذف — الكوبون الذي يُنشأ هنا يصبح
/// قابلاً للاستخدام مباشرة من العميل في سلة التسوق
class AdminCouponsScreen extends StatelessWidget {
  const AdminCouponsScreen({super.key});

  Future<void> _openForm(BuildContext context, {Coupon? coupon}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _CouponForm(coupon: coupon),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Coupon coupon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.deleteCoupon),
        content: Text('${AppStrings.confirmDelete}\n${coupon.code}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await CouponAdminService.instance.deleteCoupon(coupon.code);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Coupon>>(
      stream: CouponAdminService.instance.watchCoupons(),
      builder: (context, snapshot) {
        final coupons = snapshot.data ?? const <Coupon>[];
        final activeCount = coupons.where((c) => c.isValid).length;

        return Column(
          children: [
            AdminPageHeader(
              icon: Icons.confirmation_num_outlined,
              title: AppStrings.adminCoupons,
              subtitle:
                  '${coupons.length} ${AppStrings.coupon} • $activeCount ${AppStrings.active}',
              actions: [
                FilledButton.icon(
                  onPressed: () => _openForm(context),
                  icon: const Icon(Icons.add),
                  label: const Text(AppStrings.addCoupon),
                ),
              ],
            ),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : coupons.isEmpty
                      ? const AdminEmptyState(
                          icon: Icons.confirmation_num_outlined,
                          title: AppStrings.noCoupons,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          itemCount: coupons.length,
                          itemBuilder: (context, i) => _CouponTile(
                            coupon: coupons[i],
                            onEdit: () =>
                                _openForm(context, coupon: coupons[i]),
                            onDelete: () => _delete(context, coupons[i]),
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _CouponTile extends StatelessWidget {
  const _CouponTile({
    required this.coupon,
    required this.onEdit,
    required this.onDelete,
  });

  final Coupon coupon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String get _valueLabel {
    switch (coupon.type) {
      case CouponType.percentage:
        return '${coupon.discountValue.toStringAsFixed(0)}%';
      case CouponType.fixed:
        return CurrencyFormatter.formatClean(coupon.discountValue);
      case CouponType.freeShipping:
        return AppStrings.freeShipping;
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = coupon.isValid;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    coupon.code,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                StatusPill(
                  label: valid ? AppStrings.active : AppStrings.inactive,
                  color: valid ? AppColors.success : AppColors.error,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _chip(context, Icons.percent, _valueLabel),
                if (coupon.minOrderAmount > 0)
                  _chip(
                    context,
                    Icons.shopping_bag_outlined,
                    '${AppStrings.minOrder} ${CurrencyFormatter.formatClean(coupon.minOrderAmount)}',
                  ),
                if (coupon.usageLimit != null)
                  _chip(
                    context,
                    Icons.confirmation_num_outlined,
                    '${coupon.usedCount}/${coupon.usageLimit}',
                  ),
                if (coupon.expiryDate != null)
                  _chip(
                    context,
                    Icons.event_outlined,
                    '${coupon.expiryDate!.day}/${coupon.expiryDate!.month}/${coupon.expiryDate!.year}',
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text(AppStrings.edit),
                ),
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text(AppStrings.delete),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// نموذج إنشاء/تعديل كوبون
class _CouponForm extends StatefulWidget {
  const _CouponForm({this.coupon});

  final Coupon? coupon;

  @override
  State<_CouponForm> createState() => _CouponFormState();
}

class _CouponFormState extends State<_CouponForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _value;
  late final TextEditingController _minOrder;
  late final TextEditingController _maxDiscount;
  late final TextEditingController _usageLimit;

  CouponType _type = CouponType.percentage;
  CouponAudience _audience = CouponAudience.all;
  late final TextEditingController _minSpent;
  DateTime? _expiry;
  bool _isActive = true;
  bool _notifyAudience = true;
  bool _saving = false;

  bool get _isEdit => widget.coupon != null;

  @override
  void initState() {
    super.initState();
    final c = widget.coupon;
    _code = TextEditingController(text: c?.code ?? '');
    _value = TextEditingController(
      text: c == null ? '' : c.discountValue.toStringAsFixed(0),
    );
    _minOrder = TextEditingController(
      text: (c?.minOrderAmount ?? 0) > 0
          ? c!.minOrderAmount.toStringAsFixed(0)
          : '',
    );
    _maxDiscount = TextEditingController(
      text: c?.maxDiscount?.toStringAsFixed(0) ?? '',
    );
    _usageLimit = TextEditingController(
      text: c?.usageLimit?.toString() ?? '',
    );
    _type = c?.type ?? CouponType.percentage;
    _audience = c?.audience ?? CouponAudience.all;
    _minSpent = TextEditingController(
      text: (c?.minTotalSpent ?? 0) > 0
          ? c!.minTotalSpent.toStringAsFixed(0)
          : '',
    );
    _expiry = c?.expiryDate;
    _isActive = c?.isActive ?? true;
    // عند التعديل لا نُرسل إشعاراً افتراضياً حتى لا يتكرر على العملاء
    _notifyAudience = c == null;
  }

  @override
  void dispose() {
    _code.dispose();
    _value.dispose();
    _minOrder.dispose();
    _maxDiscount.dispose();
    _usageLimit.dispose();
    _minSpent.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final coupon = Coupon(
      code: _code.text.trim().toUpperCase(),
      type: _type,
      discountValue: _type == CouponType.freeShipping
          ? 0
          : double.tryParse(_value.text.trim()) ?? 0,
      minOrderAmount: double.tryParse(_minOrder.text.trim()) ?? 0,
      maxDiscount: _maxDiscount.text.trim().isEmpty
          ? null
          : double.tryParse(_maxDiscount.text.trim()),
      expiryDate: _expiry,
      usageLimit: _usageLimit.text.trim().isEmpty
          ? null
          : int.tryParse(_usageLimit.text.trim()),
      // لا نصفّر عدّاد الاستخدام عند التعديل
      usedCount: widget.coupon?.usedCount ?? 0,
      isActive: _isActive,
      audience: _audience,
      minTotalSpent: _audience == CouponAudience.bigSpenders
          ? (double.tryParse(_minSpent.text.trim()) ?? 0)
          : 0,
    );

    try {
      await CouponAdminService.instance.saveCoupon(coupon);
      if (_notifyAudience) {
        unawaited(CouponAdminService.instance.notifyAudience(coupon));
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.couponSaved)),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPercentage = _type == CouponType.percentage;
    final isFreeShipping = _type == CouponType.freeShipping;

    return Form(
      key: _formKey,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            _isEdit ? AppStrings.editCoupon : AppStrings.addCoupon,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _code,
            enabled: !_isEdit,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: AppStrings.couponCode,
              hintText: 'WELCOME10',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? AppStrings.required
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<CouponType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: AppStrings.couponType),
            items: [
              DropdownMenuItem(
                value: CouponType.percentage,
                child: Text(AppStrings.couponPercentage),
              ),
              DropdownMenuItem(
                value: CouponType.fixed,
                child: Text(AppStrings.couponFixed),
              ),
              DropdownMenuItem(
                value: CouponType.freeShipping,
                child: Text(AppStrings.freeShipping),
              ),
            ],
            onChanged: (v) =>
                setState(() => _type = v ?? CouponType.percentage),
          ),
          if (!isFreeShipping) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _value,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isPercentage
                    ? AppStrings.discountPercent
                    : AppStrings.discountAmount,
                suffixText: isPercentage ? '%' : 'ر.س',
              ),
              validator: (v) {
                final value = double.tryParse(v?.trim() ?? '');
                if (value == null || value <= 0) return AppStrings.invalidPrice;
                if (isPercentage && value > 100) return AppStrings.invalidPrice;
                return null;
              },
            ),
          ],
          if (isPercentage) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxDiscount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: AppStrings.maxDiscount,
                suffixText: 'ر.س',
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _minOrder,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: AppStrings.minOrderAmount,
              suffixText: 'ر.س',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _usageLimit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: AppStrings.usageLimit,
            ),
          ),
          const SizedBox(height: 12),

          // فئة العملاء المستهدفة
          DropdownButtonFormField<CouponAudience>(
            initialValue: _audience,
            decoration: const InputDecoration(
              labelText: AppStrings.couponAudience,
            ),
            items: [
              DropdownMenuItem(
                value: CouponAudience.all,
                child: Text(AppStrings.audienceAll),
              ),
              DropdownMenuItem(
                value: CouponAudience.newCustomers,
                child: Text(AppStrings.audienceNew),
              ),
              DropdownMenuItem(
                value: CouponAudience.bigSpenders,
                child: Text(AppStrings.audienceBigSpenders),
              ),
            ],
            onChanged: (v) =>
                setState(() => _audience = v ?? CouponAudience.all),
          ),
          if (_audience == CouponAudience.bigSpenders) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _minSpent,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: AppStrings.minTotalSpent,
                suffixText: 'ر.س',
                hintText: '10000',
              ),
              validator: (v) {
                final value = double.tryParse(v?.trim() ?? '');
                return (value == null || value <= 0)
                    ? AppStrings.invalidPrice
                    : null;
              },
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(AppStrings.notifyAudience),
            subtitle: Text(
              AppStrings.notifyAudienceHint,
              style: const TextStyle(fontSize: 11),
            ),
            value: _notifyAudience,
            onChanged: (v) => setState(() => _notifyAudience = v),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickExpiry,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _expiry == null
                  ? AppStrings.noExpiry
                  : '${AppStrings.expiryDate}: ${_expiry!.day}/${_expiry!.month}/${_expiry!.year}',
            ),
          ),
          if (_expiry != null)
            TextButton(
              onPressed: () => setState(() => _expiry = null),
              child: const Text(AppStrings.removeExpiry),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(AppStrings.active),
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? AppStrings.saveChanges : AppStrings.addCoupon),
            ),
          ),
        ],
      ),
    );
  }
}
