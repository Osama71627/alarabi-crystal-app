import 'dart:convert';
import 'dart:typed_data';

import 'package:alarabi_crystal/shared/services/review_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.statusCode = 200, this.body = const {}});

  int statusCode;
  Map<String, dynamic> body;

  RequestOptions? lastRequest;
  Map<String, dynamic>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    lastBody = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : null;
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ReviewApi _buildApi(_FakeAdapter adapter, {String? token = 'valid-id-token'}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ReviewApi(dio: dio, tokenProvider: () async => token);
}

void main() {
  group('إرسال رمز الهوية', () {
    test('يُرسل رمز الهوية في ترويسة Authorization', () async {
      final adapter = _FakeAdapter(body: {'ok': true});
      await _buildApi(adapter).upsert(productId: 'p1', rating: 5);
      expect(adapter.lastRequest!.headers['Authorization'], 'Bearer valid-id-token');
    });

    test('بلا رمز هوية لا يُرسل طلب إطلاقاً', () async {
      final adapter = _FakeAdapter(body: {'ok': true});
      final api = _buildApi(adapter, token: null);
      await expectLater(
        api.upsert(productId: 'p1', rating: 5),
        throwsA(isA<ReviewApiException>()
            .having((e) => e.code, 'code', 'no_id_token')),
      );
      expect(adapter.lastRequest, isNull);
    });
  });

  group('ما يُرسَل إلى الخادم', () {
    test('upsert لا يُرسل userId ولا rating/reviewCount خاصين بالمنتج', () async {
      final adapter = _FakeAdapter(body: {'ok': true, 'rating': 4.5, 'reviewCount': 3});
      await _buildApi(adapter).upsert(productId: 'p1', rating: 5, comment: 'ممتاز');

      final keys = adapter.lastBody!.keys.toSet();
      expect(keys, {'productId', 'rating', 'comment', 'userName', 'images'});
      expect(keys.contains('userId'), isFalse);
      expect(keys.contains('reviewCount'), isFalse);
    });

    test('delete يرسل action=delete بلا حقول أخرى', () async {
      final adapter = _FakeAdapter(body: {'ok': true, 'deleted': true});
      await _buildApi(adapter).delete('p1');

      expect(adapter.lastBody, {'productId': 'p1', 'action': 'delete'});
    });
  });

  group('معالجة الأخطاء', () {
    test('400 (تقييم خارج المدى) خطأ نهائي', () async {
      final adapter = _FakeAdapter(
        statusCode: 400,
        body: {'error': 'bad_rating', 'message': 'التقييم يجب أن يكون بين 1 و 5'},
      );
      await expectLater(
        _buildApi(adapter).upsert(productId: 'p1', rating: 5),
        throwsA(isA<ReviewApiException>()
            .having((e) => e.code, 'code', 'bad_rating')),
      );
    });

    test('401 خطأ نهائي', () async {
      final adapter = _FakeAdapter(statusCode: 401, body: {'error': 'unauthorized'});
      await expectLater(
        _buildApi(adapter).upsert(productId: 'p1', rating: 5),
        throwsA(isA<ReviewApiException>()),
      );
    });

    test('500 عطل تقني مؤقت', () async {
      final adapter = _FakeAdapter(statusCode: 500, body: {});
      await expectLater(
        _buildApi(adapter).upsert(productId: 'p1', rating: 5),
        throwsA(isA<ReviewApiUnavailable>()),
      );
    });
  });
}
