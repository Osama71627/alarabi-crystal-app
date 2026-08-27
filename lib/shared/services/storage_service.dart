import 'dart:typed_data';

import 'package:dio/dio.dart';

/// نتيجة رفع صورة عبر Cloudinary
class UploadResult {
  const UploadResult({required this.url, required this.publicId});

  /// رابط الصورة الجاهز للعرض
  final String url;

  /// معرّف الصورة في Cloudinary
  final String publicId;
}

/// خدمة التخزين - رفع الصور عبر Cloudinary برفع غير موقّع (Unsigned Upload
/// Preset)
///
/// كان الرفع سابقاً موقّعاً عبر Cloud Function (توقيع بمفتاح سري لا يغادر
/// الخادم)، لكن مشروع Firebase على خطة Spark المجانية لا تدعم Cloud
/// Functions إطلاقاً. البديل المجاني الوحيد هو Unsigned Upload Preset —
/// إعداد على حساب Cloudinary نفسه (وليس بالتطبيق) يسمح بالرفع المباشر من
/// العميل بدون توقيع، مقيّداً بصيغ/حجم الملف المسموحة فقط.
///
/// ملاحظة أمان: أي شخص يفكّك التطبيق (decompile) يقدر يرى اسم الـpreset
/// واسم الحساب (cloudName) ويرفع ملفات مباشرة لحساب Cloudinary هذا خارج
/// التطبيق تماماً — لا يوجد تحقق من الهوية على مستوى الرفع نفسه (يبقى
/// التحقق من صلاحية الإدارة لحفظ رابط الصورة داخل مستند منتج عبر قواعد
/// Firestore). المخاطرة محدودة عملياً باستهلاك حصة التخزين المجانية عند
/// حساب Cloudinary، وليست تكلفة مالية مباشرة.
class StorageService {
  StorageService._internal();
  static final StorageService instance = StorageService._internal();

  static const String _cloudName = 'hmgxjl7g';
  static const String _uploadPreset = 'alarabi_crystal';

  final Dio _dio = Dio();

  Future<UploadResult> _upload({
    required String folder,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    final publicId =
        '${DateTime.now().millisecondsSinceEpoch}-${bytes.length}';
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: '$publicId.$extension'),
      'upload_preset': _uploadPreset,
      'folder': folder,
      'public_id': publicId,
    });
    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      data: formData,
    );
    final data = response.data ?? const <String, dynamic>{};
    final url = data['secure_url'] as String?;
    final returnedPublicId = data['public_id'] as String?;
    if (url == null || url.isEmpty) {
      throw CloudinaryUploadException('upload_failed');
    }
    return UploadResult(url: url, publicId: returnedPublicId ?? publicId);
  }

  /// رفع صورة منتج
  Future<UploadResult> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    String extension = 'jpg',
  }) {
    return _upload(
      folder: 'products/$productId',
      bytes: bytes,
      extension: extension,
    );
  }

  /// رفع الصورة الرمزية للمستخدم الحالي
  Future<UploadResult> uploadUserAvatar({
    required Uint8List bytes,
    String extension = 'jpg',
  }) {
    return _upload(folder: 'avatars', bytes: bytes, extension: extension);
  }

  /// رفع صورة ضمن تقييم منتج
  Future<UploadResult> uploadReviewImage({
    required String productId,
    required Uint8List bytes,
    String extension = 'jpg',
  }) {
    return _upload(
      folder: 'reviews/$productId',
      bytes: bytes,
      extension: extension,
    );
  }
}

/// خطأ رفع صورة
class CloudinaryUploadException implements Exception {
  CloudinaryUploadException(this.message);

  final String message;
}
