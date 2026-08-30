import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/cart_service.dart';
import '../../../../shared/services/currency_formatter.dart';
import '../../../../shared/services/loyalty_service.dart';
import '../../../../shared/services/order_api.dart';
import '../../../../shared/services/order_service.dart';
import '../../../../shared/services/order_totals.dart';
import '../../../../shared/widgets/location_picker_screen.dart';

/// شاشة تأكيد الطلب والدفع
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final CartService _cartService = CartService.instance;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  int _paymentMethod = 0; // 0 = COD, 1 = Bank Transfer
  bool _processing = false;

  /// موقع العميل على الخريطة (اختياري) — يُرسَل مع الطلب حتى تقدر الإدارة
  /// فتحه مباشرة في خرائط جوجل عند التوصيل
  double? _latitude;
  double? _longitude;

  /// معرّف محاولة الدفع الحالية.
  ///
  /// يُولَّد مرة واحدة لهذه الشاشة ويُعاد إرساله في كل محاولة — لو ضغط
  /// العميل "إتمام الطلب" مرتين، أو انقطعت الشبكة بعد وصول الطلب للخادم
  /// وأعاد المحاولة، فالخادم يتعرّف على المحاولة نفسها ويُرجع الطلب القائم
  /// بلا إنشاء طلب ثانٍ ولا خصم مخزون مرتين.
  final String _checkoutId = OrderApi.newCheckoutId();

  int _pointsBalance = 0;
  bool _usePoints = false;
  StreamSubscription<int>? _pointsSub;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      _pointsSub = LoyaltyService.instance.watchPoints(uid).listen((points) {
        if (mounted) setState(() => _pointsBalance = points);
      });
    }
  }

  @override
  void dispose() {
    _pointsSub?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  /// عدد النقاط اللي راح تُستخدم فعلياً — لا يتجاوز الرصيد ولا يتجاوز
  /// المتبقي من الإجمالي بعد الخصومات الأخرى (تقدير للعرض فقط، الخادم
  /// يعيد التحقق من هذا الرقم عند إنشاء الطلب)
  int _redeemablePoints(double remainingAfterOtherDiscounts) {
    if (!_usePoints || _pointsBalance <= 0) return 0;
    final maxByAmount = (remainingAfterOtherDiscounts * 10).floor();
    return _pointsBalance < maxByAmount ? _pointsBalance : maxByAmount;
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  Future<void> _placeOrder() async {
    final auth = AuthService.instance;
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.loginRequired)),
      );
      context.push(AppRoutes.login);
      return;
    }

    final address = [
      _nameController.text.trim(),
      _phoneController.text.trim(),
      _addressController.text.trim(),
      _cityController.text.trim(),
    ].where((e) => e.isNotEmpty).join(' - ');

    final paymentMethod = _paymentMethod == 1
        ? PaymentMethod.bankTransfer
        : PaymentMethod.cod;

    setState(() => _processing = true);

    final remainingAfterOtherDiscounts = (_cartService.subtotal -
            _cartService.couponDiscount -
            _cartService.offerDiscount)
        .clamp(0, double.infinity)
        .toDouble();
    final pointsToRedeem = _redeemablePoints(remainingAfterOtherDiscounts);

    try {
      final order = await OrderService.instance.submitOrder(
        checkoutId: _checkoutId,
        items: _cartService.items,
        paymentMethod: paymentMethod,
        couponCode: _cartService.appliedCouponCode,
        shippingAddress: address.isEmpty ? null : address,
        shippingLat: _latitude,
        shippingLng: _longitude,
        notes: _notesController.text.trim(),
        pointsToRedeem: pointsToRedeem,
      );

      // الطلب مكتمل فعلياً هنا — فشل تفريغ السلة محلياً لا يجب أن يُفهم
      // كفشل بالطلب
      try {
        await _cartService.clear();
      } catch (_) {
        // تجاهل: الطلب نجح فعلاً، فقط لم تُفرَّغ السلة محلياً
      }
      if (!mounted) return;
      context.go(AppRoutes.orderConfirmationLink(order.id, order.total));
    } on OrderException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      setState(() => _processing = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.orderFailed)),
      );
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = _cartService.subtotal;
    final discount = _cartService.couponDiscount;
    final offerDiscount = _cartService.offerDiscount;
    final freeShipping = _cartService.freeShippingApplied;
    final remainingAfterOtherDiscounts =
        (subtotal - discount - offerDiscount).clamp(0, double.infinity).toDouble();
    final redeemedPoints = _redeemablePoints(remainingAfterOtherDiscounts);
    final pointsDiscount = redeemedPoints / 10;
    final shippingFee = OrderTotals.shippingFeeFor(
      subtotal: subtotal,
      freeShippingApplied: freeShipping,
    );
    final total = OrderTotals.total(
      subtotal: subtotal,
      discount: discount + offerDiscount + pointsDiscount,
      shippingFee: shippingFee,
    );

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.orderConfirmation)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // عنوان التوصيل
          _SectionTitle(title: AppStrings.shippingAddress),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: AppStrings.name,
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              hintText: AppStrings.phone,
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText: 'الحي، الشارع، رقم المبنى',
              prefixIcon: Icon(Icons.home_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(
              hintText: 'المدينة',
              prefixIcon: Icon(Icons.location_city),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickLocation,
            icon: Icon(
              _latitude != null ? Icons.check_circle : Icons.map_outlined,
              color: _latitude != null ? AppColors.success : null,
            ),
            label: Text(
              _latitude != null
                  ? 'تم تحديد الموقع على الخريطة ✓'
                  : 'تحديد الموقع على الخريطة (اختياري)',
            ),
          ),
          const SizedBox(height: 24),

          // طريقة الدفع
          _SectionTitle(title: AppStrings.paymentMethod),
          const SizedBox(height: 12),
          _PaymentOption(
            icon: Icons.payments_outlined,
            title: AppStrings.cod,
            selected: _paymentMethod == 0,
            onTap: () => setState(() => _paymentMethod = 0),
          ),
          _PaymentOption(
            icon: Icons.account_balance_outlined,
            title: AppStrings.bankTransfer,
            selected: _paymentMethod == 1,
            onTap: () => setState(() => _paymentMethod = 1),
          ),
          const SizedBox(height: 24),

          // استخدام نقاط الولاء
          if (_pointsBalance > 0) ...[
            Card(
              child: SwitchListTile(
                value: _usePoints,
                onChanged: (v) => setState(() => _usePoints = v),
                secondary: const Icon(Icons.stars_rounded, color: AppColors.secondary),
                title: Text(AppStrings.usePointsAtCheckout),
                subtitle: Text('$_pointsBalance ${AppStrings.pointsAvailable}'),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ملاحظات
          _SectionTitle(title: 'ملاحظات على الطلب'),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'أي ملاحظات إضافية...',
            ),
          ),
          const SizedBox(height: 24),

          // ملخص
          _SectionTitle(title: 'ملخص الطلب'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(
                    label: AppStrings.subtotal,
                    value: CurrencyFormatter.format(subtotal),
                  ),
                  const SizedBox(height: 8),
                  if (discount > 0) ...[
                    _SummaryRow(
                      label: '${AppStrings.discount} (${_cartService.appliedCouponCode ?? ''})',
                      value: '-${CurrencyFormatter.format(discount)}',
                      valueColor: AppColors.success,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (offerDiscount > 0) ...[
                    _SummaryRow(
                      label: '${AppStrings.offerDiscount} (${_cartService.appliedOffer?.title ?? ''})',
                      value: '-${CurrencyFormatter.format(offerDiscount)}',
                      valueColor: AppColors.success,
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (pointsDiscount > 0) ...[
                    _SummaryRow(
                      label: '${AppStrings.redeemPoints} ($redeemedPoints)',
                      value: '-${CurrencyFormatter.format(pointsDiscount)}',
                      valueColor: AppColors.success,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _SummaryRow(
                    label: AppStrings.shipping,
                    value: shippingFee == 0
                        ? AppStrings.freeShipping
                        : CurrencyFormatter.format(shippingFee),
                  ),
                  const Divider(height: 20),
                  _SummaryRow(
                    label: AppStrings.total,
                    value: CurrencyFormatter.format(total),
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _processing ? null : _placeOrder,
            child: _processing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    '${AppStrings.confirm} • ${CurrencyFormatter.format(total)}',
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected ? AppColors.secondary.withValues(alpha: 0.1) : null,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          icon,
          color: selected ? AppColors.secondary : null,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? AppColors.secondary : Theme.of(context).colorScheme.outline,
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool isTotal;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )
              : Theme.of(context).textTheme.bodyMedium,
        ),
        Text(
          value,
          style: isTotal
              ? Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  )
              : Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: valueColor,
                    fontWeight: valueColor != null ? FontWeight.w700 : null,
                  ),
        ),
      ],
    );
  }
}
