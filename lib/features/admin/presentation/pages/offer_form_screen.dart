import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/offer.dart';
import '../../../offers/domain/repositories/offer_repository.dart';
import '../../domain/repositories/admin_repository.dart';
import '../widgets/admin_widgets.dart';

/// نموذج إضافة/تعديل عرض
class OfferFormScreen extends StatefulWidget {
  const OfferFormScreen({super.key, this.offer});

  final Offer? offer;

  @override
  State<OfferFormScreen> createState() => _OfferFormScreenState();
}

class _OfferFormScreenState extends State<OfferFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _discountValue;
  late final TextEditingController _minPurchase;
  late final TextEditingController _maxDiscount;
  late final TextEditingController _usageLimit;
  late final TextEditingController _perUserLimit;
  late final TextEditingController _buyQuantity;
  late final TextEditingController _getQuantity;

  OfferType _type = OfferType.percentage;
  OfferApplicableType _applicableType = OfferApplicableType.all;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.offer != null;

  @override
  void initState() {
    super.initState();
    final o = widget.offer;
    _title = TextEditingController(text: o?.title ?? '');
    _description = TextEditingController(text: o?.description ?? '');
    _discountValue = TextEditingController(
      text: o != null ? o.discountValue.toString() : '',
    );
    _minPurchase = TextEditingController(
      text: o != null && o.minPurchase > 0 ? o.minPurchase.toString() : '',
    );
    _maxDiscount = TextEditingController(
      text: o?.maxDiscount?.toString() ?? '',
    );
    _usageLimit =
        TextEditingController(text: o?.usageLimit?.toString() ?? '');
    _perUserLimit =
        TextEditingController(text: o?.perUserLimit?.toString() ?? '');
    _buyQuantity = TextEditingController(
      text: o != null && o.buyQuantity > 0 ? o.buyQuantity.toString() : '',
    );
    _getQuantity = TextEditingController(
      text: o != null && o.getQuantity > 0 ? o.getQuantity.toString() : '',
    );
    _type = o?.type ?? OfferType.percentage;
    _applicableType = o?.applicableType ?? OfferApplicableType.all;
    _startDate = o?.startDate;
    _endDate = o?.endDate;
    _isActive = o?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _discountValue.dispose();
    _minPurchase.dispose();
    _maxDiscount.dispose();
    _usageLimit.dispose();
    _perUserLimit.dispose();
    _buyQuantity.dispose();
    _getQuantity.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? now,
      firstDate: isStart ? DateTime(2020) : now,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final value = double.tryParse(_discountValue.text) ?? 0;
    if (value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.invalidValue)),
      );
      return;
    }
    setState(() => _saving = true);

    final offer = Offer(
      id: widget.offer?.id ??
          'o-${DateTime.now().millisecondsSinceEpoch}',
      title: _title.text.trim(),
      description: _description.text.trim(),
      type: _type,
      discountValue: value,
      applicableType: _applicableType,
      applicableIds: widget.offer?.applicableIds ?? const [],
      minPurchase: double.tryParse(_minPurchase.text) ?? 0,
      maxDiscount: _maxDiscount.text.trim().isEmpty
          ? null
          : double.tryParse(_maxDiscount.text),
      usageLimit: _usageLimit.text.trim().isEmpty
          ? null
          : int.tryParse(_usageLimit.text),
      usedCount: widget.offer?.usedCount ?? 0,
      perUserLimit: _perUserLimit.text.trim().isEmpty
          ? null
          : int.tryParse(_perUserLimit.text),
      startDate: _startDate,
      endDate: _endDate,
      isActive: _isActive,
      bannerImage: widget.offer?.bannerImage,
      displayOrder: widget.offer?.displayOrder ?? 0,
      buyQuantity: int.tryParse(_buyQuantity.text) ?? 0,
      getQuantity: int.tryParse(_getQuantity.text) ?? 0,
    );

    final repo = sl<OfferRepository>();
    try {
      if (_isEdit) {
        await repo.updateOffer(offer);
      } else {
        await repo.addOffer(offer);
        // إشعار المستخدمين عند نشر عرض جديد (لا يمنع فشله حفظ العرض)
        unawaited(_sendNewOfferNotification(offer));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.saveFailed)),
        );
      }
    }
  }

  /// تسجيل إشعار "عرض جديد" يُرسل لجميع المستخدمين عبر Cloud Function
  Future<void> _sendNewOfferNotification(Offer offer) async {
    try {
      await sl<AdminRepository>().sendNotification(
        AdminNotification(
          id: 'n-${DateTime.now().millisecondsSinceEpoch}',
          title: AppStrings.newOfferNotifTitle,
          body: AppStrings.newOfferNotifBody
              .replaceFirst('{name}', offer.title),
          target: NotificationTarget.all,
          type: 'offer',
          linkId: offer.id,
          createdAt: DateTime.now(),
        ),
      );
    } catch (_) {
      // تجاهل — فشل الإشعار لا يمنع نشر العرض
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? AppStrings.editOffer : AppStrings.createOffer),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AdminSectionCard(
              title: 'معلومات العرض',
              icon: Icons.local_offer_outlined,
              child: Column(
                children: [
                  TextFormField(
                    controller: _title,
                    decoration:
                        const InputDecoration(labelText: AppStrings.offerTitle),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? AppStrings.required
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: AppStrings.description),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<OfferType>(
                    initialValue: _type,
                    decoration:
                        const InputDecoration(labelText: AppStrings.offerType),
                    items: [
                      for (final type in OfferType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(_typeLabel(type)),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _type = v ?? OfferType.percentage),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _discountValue,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: AppStrings.discountValue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            AdminSectionCard(
              title: 'شروط التطبيق',
              icon: Icons.rule_outlined,
              child: Column(
                children: [
                  DropdownButtonFormField<OfferApplicableType>(
                    initialValue: _applicableType,
                    decoration:
                        const InputDecoration(labelText: AppStrings.offerScope),
                    items: [
                      for (final type in OfferApplicableType.values)
                        DropdownMenuItem(
                          value: type,
                          child: Text(_scopeLabel(type)),
                        ),
                    ],
                    onChanged: (v) => setState(
                        () => _applicableType = v ?? OfferApplicableType.all),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minPurchase,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: AppStrings.minPurchase,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _maxDiscount,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: AppStrings.maxDiscount,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_type == OfferType.bundle) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _buyQuantity,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: AppStrings.buyQuantity,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _getQuantity,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: AppStrings.getQuantity,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            AdminSectionCard(
              title: 'الفترة والحالة',
              icon: Icons.event_available_outlined,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(isStart: true),
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(
                            _startDate == null
                                ? AppStrings.startDate
                                : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDate(isStart: false),
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(
                            _endDate == null
                                ? AppStrings.endDate
                                : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(AppStrings.active),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

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
                    : Text(_isEdit ? AppStrings.saveChanges : AppStrings.createOffer),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(OfferType type) {
    switch (type) {
      case OfferType.percentage:
        return AppStrings.percentageOffers;
      case OfferType.fixed:
        return AppStrings.fixedOffers;
      case OfferType.bundle:
        return AppStrings.bundleOffers;
      case OfferType.cart:
        return AppStrings.cartOffers;
      case OfferType.flash:
        return AppStrings.flashOffers;
      case OfferType.member:
        return AppStrings.memberOffers;
    }
  }

  String _scopeLabel(OfferApplicableType type) {
    switch (type) {
      case OfferApplicableType.product:
        return AppStrings.specificProduct;
      case OfferApplicableType.category:
        return AppStrings.specificCategory;
      case OfferApplicableType.all:
        return AppStrings.allProducts;
    }
  }
}
