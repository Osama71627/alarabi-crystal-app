import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../shared/data/demo_data.dart';

/// أداة رفع البيانات التجريبية إلى Firestore
///
/// التشغيل:
///   flutter run -t lib/tools/seed_firestore.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _SeedApp());
}

class _SeedApp extends StatelessWidget {
  const _SeedApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const _SeedScreen(),
    );
  }
}

class _SeedScreen extends StatefulWidget {
  const _SeedScreen();

  @override
  State<_SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<_SeedScreen> {
  final List<String> _logs = <String>[];
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _log(String message) {
    debugPrint('[seed] $message');
    setState(() {
      _logs.add(message);
      if (_logs.length > 40) _logs.removeAt(0);
    });
  }

  Future<void> _run() async {
    await Firebase.initializeApp();
    final db = FirebaseFirestore.instance;

    _log('البدء... الفئات ${DemoData.categories.length}، المنتجات ${DemoData.products.length}، البنرات ${DemoData.banners.length}، العروض ${DemoData.offers.length}');

    var ok = 0;
    var fail = 0;

    Future<void> write(String coll, String id, Map<String, dynamic> data) async {
      for (var attempt = 0; attempt < 4; attempt++) {
        try {
          await db.collection(coll).doc(id).set(data).timeout(const Duration(seconds: 20));
          ok++;
          _log('تم $coll/$id');
          return;
        } catch (e) {
          fail++;
          _log('محاولة $attempt لـ $coll/$id فشلت: $e');
          await Future<void>.delayed(const Duration(seconds: 3));
        }
      }
    }

    for (final c in DemoData.categories) {
      await write('categories', c.id, c.toMap());
    }
    for (final p in DemoData.products) {
      await write('products', p.id, p.toMap());
    }
    for (final b in DemoData.banners) {
      await write('banners', b.id, b.toMap());
    }
    for (final o in DemoData.offers) {
      await write('offers', o.id, o.toMap());
    }
    // كوبونات تجريبية (الرمز = معرف المستند)
    final demoCoupons = {
      'WELCOME10': {
        'type': 'percentage',
        'discountValue': 10,
        'minOrderAmount': 100,
        'maxDiscount': 100,
        'isActive': true,
      },
      'SAVE50': {
        'type': 'fixed',
        'discountValue': 50,
        'minOrderAmount': 300,
        'isActive': true,
      },
      'FREESHIP': {
        'type': 'freeShipping',
        'discountValue': 0,
        'minOrderAmount': 150,
        'isActive': true,
      },
    };
    for (final entry in demoCoupons.entries) {
      await write('coupons', entry.key, entry.value);
    }

    _log('✅ اكتمل: نجح $ok، فشل $fail');
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_done) const CircularProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                'رفع البيانات إلى Firestore',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                height: 240,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF12263A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, i) => Text(
                    _logs[i],
                    style: const TextStyle(color: Color(0xFF7FB8FF), fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
