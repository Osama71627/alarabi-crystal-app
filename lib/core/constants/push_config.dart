/// إعدادات خادم إرسال إشعارات الدفع الخارجي (push-server/ على Vercel)
///
/// إن أُفرغ [baseUrl] يتعطّل إرسال الإشعار الفوري (Push) بصمت — الإشعار
/// داخل التطبيق حين يكون مفتوحاً (InAppNotificationService) يستمر يعمل
/// دائماً بلا حاجة لهذا الخادم إطلاقاً.
///
/// ⚠️ المرحلة 13: لا يوجد هنا أي سرّ ثابت بعد الآن. الحماية أصبحت رمز
/// هوية Firebase (يُرسَل مباشرة من `PushTriggerService`، لا يُخزَّن هنا) —
/// راجع تقرير المرحلة 12 (الثغرة C1) لسبب إزالة السرّ القديم.
class PushConfig {
  PushConfig._();

  static const String baseUrl = 'https://alarabi-push.vercel.app/api/notify';

  static bool get isConfigured => baseUrl.isNotEmpty;
}
