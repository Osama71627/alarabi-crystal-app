import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../injection.dart';
import '../shared/models/cart_item.dart';
import '../shared/models/order.dart';
import '../shared/services/auth_service.dart';
import '../shared/services/cart_service.dart';
import '../shared/services/order_api.dart';
import '../shared/services/order_service.dart';

/// أداة اختبار: تتحقق من المزامنة السحابية للمفضلة/السلة/الطلبات
/// تُطبع النتائج بعلامة [cloudtest] في logcat وتُعرض على الشاشة
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupLocator();
  runApp(const _CloudSyncTestApp());
}

class _CloudSyncTestApp extends StatefulWidget {
  const _CloudSyncTestApp();

  @override
  State<_CloudSyncTestApp> createState() => _CloudSyncTestAppState();
}

class _CloudSyncTestAppState extends State<_CloudSyncTestApp> {
  String _log = '';
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _log = '';
    });
    final lines = <String>[];
    void log(String message) {
      debugPrint('[cloudtest] $message');
      lines.add(message);
    }

    try {
      final auth = AuthService.instance;
      final email = 'cloudtest${DateTime.now().millisecondsSinceEpoch}@test.com';
      log('1-register');
      final user = await auth.registerWithEmail(
        name: 'Cloud Tester',
        email: email,
        phone: '0500000000',
        password: 'Test@123456',
      );
      log('2-user=${user.uid}');

      var updated = await auth.toggleFavorite('p1');
      updated = await auth.toggleFavorite('p3');
      log('3-favorites=${updated.favorites.join(',')}');

      final cart = CartService.instance;
      await cart.addItem(CartItem(
        productId: 'p1',
        name: 'TEST CART P1',
        price: 1500,
        image: '',
        quantity: 2,
        stock: 10,
        discountPrice: 1125,
      ));
      await cart.addItem(CartItem(
        productId: 'p3',
        name: 'TEST CART P3',
        price: 800,
        image: '',
        quantity: 1,
        stock: 5,
      ));
      log('4-cartItems=${cart.items.length}, total=${cart.totalItems}');

      // ملاحظة: الطلب يُنشأ عبر الخادم الموثوق (push-server/api/order.js)
      // الذي يعيد حساب السعر من مستندات المنتجات الحقيقية — يتطلب أن تكون
      // p1/p3 مزروعة مسبقاً عبر lib/tools/seed_firestore.dart، واتصالاً
      // فعلياً بالإنترنت (هذه أداة اختبار يدوية تُشغَّل عمداً، لا جزء من
      // مجموعة الاختبارات الآلية)
      final order = await OrderService.instance.submitOrder(
        checkoutId: OrderApi.newCheckoutId(),
        items: cart.items,
        paymentMethod: PaymentMethod.cod,
        shippingAddress: 'Test Address - Riyadh',
        notes: 'cloud sync test',
      );
      log('5-orderId=${order.id}, total=${order.total.toStringAsFixed(2)}');

      final fetched = await OrderService.instance.getOrder(order.id);
      log('6-orderReadBack=${fetched != null}, status=${fetched?.status.name}');

      await for (final orders
          in OrderService.instance.watchOrders(user.uid).take(1)) {
        log('7-watchOrders=${orders.length}');
      }

      // إعادة تحميل السلة من السحابة بعد تفريغها
      await cart.clear();
      await cart.addItem(CartItem(
        productId: 'p1',
        name: 'TEST CART P1',
        price: 1500,
        image: '',
        quantity: 1,
        stock: 10,
      ));
      await cart.syncFromCloud(user.uid);
      log('8-cartReloaded=${cart.items.length}');

      log('9-currentFavorites=${auth.currentUser?.favorites.join(',')}');
      log('DONE');
    } catch (e) {
      log('ERROR: $e');
    }
    if (mounted) {
      setState(() {
        _log = lines.join('\n');
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Sync Test',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Cloud Sync Test')),
        body: Center(
          child: _running
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _log,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _run,
                        child: const Text('إعادة الاختبار'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
