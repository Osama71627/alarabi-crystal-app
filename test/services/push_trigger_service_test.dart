import 'dart:convert';
import 'dart:typed_data';

import 'package:alarabi_crystal/shared/services/push_trigger_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// محوّل شبكة وهمي: يسجّل ما أُرسل فعلاً — يثبت أن الطلب لم يعد يحمل
/// السرّ الثابت القديم (المرحلة 13 — إصلاح الثغرة C1)
class _FakeAdapter implements HttpClientAdapter {
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

PushTriggerService _buildService(_FakeAdapter adapter, {String? token}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return PushTriggerService.forTesting(
    tokenProvider: () async => token,
    dio: dio,
  );
}

void main() {
  group('PushTriggerService — بعد إزالة السرّ الثابت (المرحلة 13)', () {
    test('يُرسل رمز هوية Firebase في ترويسة Authorization', () async {
      final adapter = _FakeAdapter();
      final service = _buildService(adapter, token: 'fake-id-token');

      await service.notify(title: 't', body: 'b');

      expect(
        adapter.lastRequest!.headers['Authorization'],
        'Bearer fake-id-token',
      );
    });

    test('لا يوجد أي رأس x-shared-secret في الطلب إطلاقاً', () async {
      final adapter = _FakeAdapter();
      final service = _buildService(adapter, token: 'fake-id-token');

      await service.notify(title: 't', body: 'b');

      expect(adapter.lastRequest!.headers.containsKey('x-shared-secret'), isFalse);
    });

    test('بلا توكن (مستخدم غير مسجَّل) لا يُرسل أي طلب', () async {
      final adapter = _FakeAdapter();
      final service = _buildService(adapter, token: null);

      await service.notify(title: 't', body: 'b');

      expect(adapter.lastRequest, isNull);
    });

    test('userId يُرسَل كما هو — الخادم وحده يقرر الصلاحية', () async {
      final adapter = _FakeAdapter();
      final service = _buildService(adapter, token: 'fake-id-token');

      await service.notify(title: 't', body: 'b', userId: 'target-uid');

      final body =
          Map<String, dynamic>.from(adapter.lastRequest!.data as Map);
      expect(body['userId'], 'target-uid');
    });
  });
}
