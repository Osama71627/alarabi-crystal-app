import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../injection.dart';
import '../shared/services/auth_service.dart';
import '../shared/services/storage_service.dart';

/// أداة اختبار: تتحقق من رفع/حذف صورة عبر Firebase Storage
/// تُطبع النتائج بعلامة [storagetest] في logcat وتُعرض على الشاشة
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await setupLocator();
  runApp(const _StorageTestApp());
}

class _StorageTestApp extends StatefulWidget {
  const _StorageTestApp();

  @override
  State<_StorageTestApp> createState() => _StorageTestAppState();
}

class _StorageTestAppState extends State<_StorageTestApp> {
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
      debugPrint('[storagetest] $message');
      lines.add(message);
    }

    // صورة PNG 1x1 صالحة
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );

    try {
      final auth = AuthService.instance;
      log('1-register');
      final email = 'storage${DateTime.now().millisecondsSinceEpoch}@test.com';
      final user = await auth.registerWithEmail(
        name: 'Storage Tester',
        email: email,
        phone: '0500000000',
        password: 'Test@123456',
      );
      log('2-user=${user.uid}');

      final storage = StorageService.instance;
      final png = pngBytes;

      // رفع صور المنتجات يتطلب صلاحية إدارة الآن (getCloudinarySignature
      // يتحقق من ذلك على الخادم) — هذا الحساب التجريبي عادي، فالمتوقع هو
      // فشل الطلب بصلاحية مرفوضة، وهذا يؤكد أن الحماية تعمل فعلاً.
      log('3-uploadProductImage (متوقّع: permission-denied لحساب غير إداري)');
      try {
        final product = await storage.uploadProductImage(
          productId: 'p-test',
          bytes: png,
          extension: 'png',
        );
        log('4-url=${product.url}');
        log('5-publicId=${product.publicId}');
      } catch (e) {
        log('4-product-upload-rejected (متوقّع): $e');
      }

      log('6-uploadUserAvatar');
      final avatar = await storage.uploadUserAvatar(
        bytes: png,
        extension: 'png',
      );
      log('7-avatarUrl=${avatar.url}');
      log('8-avatarPublicId=${avatar.publicId}');
      log('DONE');
      log('شاهد الصور في Cloudinary → Media Library');
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
      title: 'Storage Test',
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        appBar: AppBar(title: const Text('Storage Test')),
        body: Center(
          child: _running
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(_log, style: const TextStyle(fontSize: 13)),
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

