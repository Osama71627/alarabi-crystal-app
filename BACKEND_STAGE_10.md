# تقرير المرحلة 10 — ربط Flutter بالخادم الموثوق

**التاريخ:** 2026-08-17
**الحالة:** مكتملة. لم تُشدَّد قواعد Firestore. لم يُنشأ أي طلب Production حقيقي.

---

## 1) الملفات التي تغيّرت

### خادم (push-server) — إضافة Idempotency

| الملف | التغيير |
|---|---|
| `push-server/lib/order-input.js` | أضاف `deriveOrderId(uid, checkoutId)` و `parseCheckoutId()` — معرّف الطلب يُشتق من SHA-256 لـ `uid:checkoutId` |
| `push-server/api/order.js` | معرّف الطلب لم يعد عشوائياً (`generateId`) بل مشتقاً من `checkoutId`. قبل الكتابة يقرأ الخادم `orders/{orderId}` ضمن نفس المعاملة: إن كان موجوداً يُرجعه كما هو (`duplicate: true`) بلا أي كتابة جديدة. كما أضاف معالجة تعارض `commit` (طلبان متزامنان بنفس المعرّف) |
| `push-server/test/order-core.test.js` + `push-server/test/pricing.test.js` | 5 اختبارات جديدة لمنع التكرار |

### تطبيق Flutter — طبقة الاتصال بالخادم

| الملف | التغيير |
|---|---|
| `lib/core/constants/backend_config.dart` (جديد) | رابط الخادم (`/api/order`, `/api/review`) |
| `lib/shared/services/order_api.dart` (جديد) | `OrderApi.createOrder()` — يرسل الطلب، يرفق رمز الهوية، يصنّف الأخطاء إلى `OrderApiException` (نهائي) أو `OrderApiUnavailable` (مؤقت). `OrderApi.newCheckoutId()` يولّد معرّف محاولة دفع |
| `lib/shared/services/order_service.dart` | أضاف `submitOrder()` كمسار أساسي جديد (ينادي الخادم أولاً، ويلجأ لـ `placeOrder()` القديم فقط عند عطل تقني). `placeOrder()` القديم لم يُحذف ولم يتغيّر |
| `lib/features/cart/presentation/pages/checkout_screen.dart` | يستدعي `submitOrder()` بدل `placeOrder()`، مع `_checkoutId` ثابت طوال حياة الشاشة |

### اختبارات جديدة

| الملف | العدد |
|---|---|
| `test/services/order_api_test.dart` | 17 اختباراً |
| `test/services/order_submit_fallback_test.dart` | 4 اختبارات |
| `push-server/test/*.test.js` (إضافات) | 5 اختبارات |

---

## 2) طريقة إرسال Firebase ID Token

```dart
final token = await FirebaseAuth.instance.currentUser?.getIdToken();
```

`getIdToken()` يجدّد الرمز تلقائياً إن قارب الانتهاء. يُرسَل في الترويسة:

```
Authorization: Bearer <id-token>
```

بلا رمز صالح، `OrderApi` لا يرسل أي طلب شبكة أصلاً ويرمي `OrderApiException` بحالة 401 محلياً (اختبار: "بلا رمز هوية لا يُرسل طلب إطلاقاً").

الخادم يتحقق من التوقيع بنفسه (`push-server/lib/google-auth.js`) ولا يثق بأي `userId` يصل في جسم الطلب.

---

## 3) بنية طلب/رد API

### الطلب — `POST /api/order`

```
Authorization: Bearer <firebase-id-token>
Content-Type: application/json
```

```json
{
  "checkoutId": "24 حرفاً عشوائياً — معرّف محاولة الدفع",
  "items": [
    { "productId": "p1", "quantity": 2 }
  ],
  "couponCode": "SAVE10",
  "paymentMethod": "cod",
  "shippingAddress": "نص العنوان",
  "notes": "ملاحظات اختيارية",
  "pointsToRedeem": 50
}
```

**لا يوجد في الجسم:** `price` · `discountPrice` · `subtotal` · `discount` · `total` · `shippingFee` · `stock` · `soldCount` · `usedCount` · `userId` · `status`. هذه القيم كلها يحسبها الخادم من Firestore، ولا يقرأها من جسم الطلب حتى لو أُرسلت (اختبار مخصص: "لا يُرسل الإجمالي ولا الخصم ولا الشحن ولا المخزون").

### الرد الناجح — `200`

```json
{
  "ok": true,
  "orderId": "معرّف مشتق من uid + checkoutId",
  "order": {
    "userId": "من التوكن",
    "items": [ /* أسعار Firestore الحقيقية */ ],
    "total": 1600,
    "status": "pending",
    "pricing": {
      "subtotal": 2000,
      "couponDiscount": 200,
      "offerDiscount": 200,
      "pointsDiscount": 0,
      "appliedOfferId": "o1",
      "redeemedPoints": 0,
      "source": "server"
    }
  }
}
```

عند تكرار نفس `checkoutId`: نفس البنية + `"duplicate": true`.

### الأخطاء

| الحالة | الفئة | مثال |
|---|---|---|
| `401` | هوية | `{"error":"unauthorized","reason":"token_expired"}` |
| `400` | رفض منطقي نهائي | `{"error":"insufficient_stock","message":"الكمية المتوفرة من ... غير كافية حالياً"}` |
| `409` | تعارض تزامن | `{"error":"conflict","message":"ازدحام مؤقت، حاول مرة أخرى"}` |
| `5xx` | عطل تقني | — |

---

## 4) طريقة معالجة الأخطاء في Flutter

`OrderApi.createOrder()` يصنّف كل استجابة إلى نوعين فقط:

```dart
if (status >= 500) throw OrderApiUnavailable(...);   // عطل مؤقت
if (status >= 400) throw OrderApiException(...);      // رفض نهائي
```

انقطاع الشبكة أو انتهاء المهلة (`DioException`) → `OrderApiUnavailable` أيضاً.

في `OrderService.submitOrder()`:

```dart
try {
  return await orderApi.createOrder(...);
} on OrderApiException catch (e) {
  throw OrderException(e.message);       // يُعرض للعميل — لا مسار بديل
} on OrderApiUnavailable catch (_) {
  lastOrderUsedFallback = true;          // فقط هنا يُجرَّب المسار القديم
}
return placeOrder(...);                  // المسار المحلي القديم (مؤقت)
```

**النتيجة المطابقة للشرط المطلوب:**
- كل أكواد التحقق (`insufficient_stock`, `coupon_expired`, `coupon_invalid`, `coupon_exhausted`, `coupon_audience`, `bad_quantity`, …) → 400 → `OrderApiException` → تُعرض للعميل مباشرة، **بدون أي fallback**.
- `409` (تعارض/ازدحام) → `OrderApiException` أيضاً — خطأ نهائي، ليس عطلاً تقنياً، فلا fallback.
- فقط `5xx` وانقطاع الشبكة والمهلة → `OrderApiUnavailable` → المسار البديل المؤقت.

مُختبر صراحة في `order_api_test.dart` (مجموعة "كل أخطاء التحقق تبقى نهائية ولا تتحول لعطل مؤقت" — 11 كوداً) و`order_submit_fallback_test.dart` (يثبت أن `lastOrderUsedFallback` يبقى `false` عند الرفض النهائي، ولا يصبح `true` إلا عند `OrderApiUnavailable`).

---

## 5) طريقة منع الطلبات المكررة (Idempotency)

**معرّف طلب حتمي مشتق من (صاحب الطلب + معرّف المحاولة):**

```js
// push-server/lib/order-input.js
function deriveOrderId(uid, checkoutId) {
  return crypto.createHash('sha256')
    .update(`${uid}:${checkoutId}`)
    .digest('base64url')
    .slice(0, 22);
}
```

- `checkoutId` يُولَّد **مرة واحدة** في `CheckoutScreen` (حقل `final`) ويُعاد إرساله كما هو في أي إعادة محاولة ضمن نفس الشاشة — ضغطتان على الزر أو إعادة محاولة بعد انقطاع شبكة تحملان نفس المعرّف.
- الخادم يقرأ `orders/{orderId}` **داخل نفس المعاملة** قبل أي كتابة. إن كان المستند موجوداً: لا كتابة جديدة إطلاقاً، يُعاد الطلب القائم بعلامة `duplicate: true`.
- تصادم متزامن حقيقي (طلبان بنفس المعرّف يصلان في نفس اللحظة): شرط `currentDocument.exists:false` على كتابة الطلب يجعل أحدهما فقط ينجح؛ الآخر يفشل بـ `ALREADY_EXISTS`/`FAILED_PRECONDITION` فيقرأ الخادم الطلب الفائز ويُرجعه بدل رمي خطأ.
- إدماج المخزون: نفس المنتج مكرراً في السلة يُدمج بكمية واحدة (`push-server/lib/order-input.js: parseItems`) — يمنع حساب المخزون مرتين حتى ضمن نفس الطلب.

**النتيجة:** طلبان لا يمكن أن ينتجا أبداً — لا خصم مخزون مضاعف، لا استهلاك كوبون مضاعف، لا نقاط مضاعفة (النقاط أصلاً تُمنح لاحقاً من الإدارة بحماية `pointsAwarded` منفصلة تماماً).

**مُختبر بـ:**
- `push-server/test/order-core.test.js`: توليد معرّف حتمي، عدم تصادم بين مستخدمين مختلفين بنفس `checkoutId`، رفض معرّف محاولة غير صالح.
- `test/services/order_api_test.dart`: "إعادة المحاولة بنفس المعرّف تُعيد نفس الطلب دون إنشاء ثانٍ".

---

## 6) نتيجة flutter analyze

```
5 issues found (ran in 18.8s)
```

كلها `info` تجميلية قديمة غير مرتبطة بهذا التغيير (`prefer_initializing_formals`, `use_null_aware_elements` في ملفين لم يُلمسا). **صفر أخطاء.**

## 7) نتيجة flutter test

```
183/183 ناجح (كانت 162 قبل هذه المرحلة)
```

شُغِّلت السلسلة الكاملة **مرتين متتاليتين** للتأكد من عدم التذبذب (flakiness) — نجحت في الاثنتين.

**ملاحظة جانبية:** أثناء هذا التشغيل ظهر تذبذب في اختبار قديم غير مرتبط (`offer_model_test.dart`: `remainingTime`) كان يقارن `Duration.inHours` بعدد صحيح، فيفشل أحياناً بفارق أجزاء ثانية بين إنشاء الكائن وقراءة القيمة. أصلحته إلى مقارنة بنافذة دقيقة واحدة (`closeTo`) — إصلاح اختبار موجود مسبقاً، لا علاقة له بمنطق الطلبات.

الإضافة من هذه المرحلة تحديداً: **21 اختباراً جديداً** (17 + 4).

---

## 8) اختبارات التكامل التي تمت

| الاختبار | النتيجة |
|---|---|
| نشر الخادم مع Idempotency | ناجح (`● Ready`) |
| `/api/order` بلا توكن | `401 missing_token` |
| `/api/notify` (انحدار) | `401` — كما كان |
| `/api/review` بلا توكن | `401` — كما كان |
| اختبارات الخادم (`npm test`) | **61/61** |
| اختبارات Flutter (`flutter test`) | **183/183** |

**لم يُنفَّذ:** استدعاء ناجح فعلي لـ `/api/order` بتوكن حقيقي — لأنه يتطلب تسجيل دخول بكلمة مرور حقيقية (حد ثابت لا أتجاوزه) ولأنه سينشئ طلباً وينقص مخزوناً حقيقيين، وقد طلبت صراحة عدم تنفيذه بلا موافقتك.

---

## 9) هل تم إنشاء أي بيانات Production؟

**لا.** لم يُنشأ أي طلب، ولم يُخصم أي مخزون، ولم يُستهلك أي كوبون، ولم تُمنح أي نقطة. كل عمليات التحقق تمت بطلبات `401` (ترفض قبل الوصول لأي منطق كتابة) أو باختبارات بلا اتصال.

---

## 10) الـFallback الفعّال حالياً

**نعم، لا يزال فعّالاً — كما طلبت للمرحلة 10 فقط:**

- `OrderService.placeOrder()` (المعاملة المحلية القديمة) لم يُحذف ولم يتغيّر سطر واحد فيه.
- `firestore.rules` لم تتغيّر — العميل لا يزال قادراً (نظرياً) على الكتابة المباشرة إن استُدعي المسار القديم.
- يُستدعى **فقط** عند `OrderApiUnavailable` (شبكة/مهلة/5xx) — أي رفض منطقي (400/409) لا يصل إليه إطلاقاً.
- `OrderService.lastOrderUsedFallback` يكشف أي طلب استخدم المسار البديل فعلاً — أداة تشخيص متاحة لك لمراقبة عدد مرات استخدامه بعد النشر.

**يُزال في المرحلة 11** عند تشديد القواعد، بعد نجاح شراء حقيقي.

---

## 11) مخاطر متبقية قبل المرحلة 11

1. **لم يُختبَر شراء حقيقي ناجح على جهاز فعلي بعد** — كل ما سبق تحقق ساكن + اختبارات آلية. هذا هو الخطوة التالية المطلوبة صراحةً منك قبل أي تشديد.
2. **المسار القديم يبقى فعّالاً كمسار بديل** — يعني أن ثغرة تعديل `stock`/`usedCount` المباشر (موضوع القرار الأول في تقرير المراجعة الأصلي) **لم تُغلق بعد**، لأن القواعد لم تُشدَّد عمداً بطلبك.
3. **زمن استجابة أعلى قليلاً**: الخادم الجديد يحتاج ~0.5-1.5 ثانية إضافية (بدء بارد + معاملة REST) مقابل ~0.3 ثانية للمسار المحلي القديم — غير مُختبر بعد بحمل مستخدم حقيقي.
4. **حقل `pricing` جديد في مستند الطلب** لم يكن موجوداً سابقاً — الشاشات التي تعرض تفاصيل الطلب (تفاصيل الطلب للعميل/الإدارة) لم تُعدَّل لعرضه؛ ليس عطلاً (الحقول القديمة كلها موجودة كما كانت) لكنه معلومة إضافية غير مستغَلة بعد في الواجهة.

---

## الخطوة التالية

بانتظار موافقتك على تنفيذ **أول طلب حقيقي فعلي** (سيؤثر على المخزون والكوبونات والنقاط) كاختبار قبول نهائي، ثم بعد نجاحه — موافقتك المنفصلة على المرحلة 11 (تشديد `firestore.rules`).
