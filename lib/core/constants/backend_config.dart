/// إعدادات الخادم الموثوق (push-server/ على Vercel)
///
/// هذا الخادم هو **مصدر الحقيقة** للعمليات الحسّاسة: إنشاء الطلب وحساب
/// أسعاره وخصوماته وحجز مخزونه، وحساب متوسط تقييم المنتجات. التطبيق يرسل
/// ما يريده العميل فقط (معرّفات المنتجات والكميات) ولا يرسل أي مبلغ.
///
/// إن أُفرغ [host] يرجع التطبيق للمسار القديم (إنشاء الطلب محلياً) —
/// مفيد للتجربة فقط، وليس المسار المقصود. راجع push-server/README.md.
class BackendConfig {
  BackendConfig._();

  static const String host = 'https://alarabi-push.vercel.app';

  /// إنشاء الطلب — يتطلب ترويسة Authorization برمز هوية Firebase
  static const String orderUrl = '$host/api/order';

  /// حفظ مراجعة وإعادة حساب تقييم المنتج
  static const String reviewUrl = '$host/api/review';

  static bool get isConfigured => host.isNotEmpty;
}
