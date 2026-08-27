/**
 * ⚠️⚠️⚠️ ملف قديم غير مُستخدَم — لا تنشره بدون مراجعة كاملة (المرحلة 13، الثغرة M3) ⚠️⚠️⚠️
 *
 * هذا الملف من معمارية سابقة استُبدلت بالكامل بخادم push-server/ الحالي
 * (Vercel Serverless، بلا Cloud Functions لأن الخطة الحالية Spark لا
 * تدعمها إطلاقاً). لم يُنشَر ولا مرة واحدة، وغير مربوط بـ firebase.json
 * عمداً منذ المرحلة 13 (كان مربوطاً سابقاً، فأُزيل الربط تحديداً لمنع
 * `firebase deploy` غير المحدَّد النطاق من نشره بالخطأ لو تمت ترقية
 * المشروع لخطة Blaze مستقبلاً).
 *
 * لماذا الخطورة حقيقية لو نُشر كما هو:
 * - يتضمن مسار دفع Stripe **فعلي وكامل** (createPaymentIntent/
 *   confirmOrderPayment) — يتعارض مع قرار العمل الحالي (الدفع عند
 *   الاستلام/التحويل البنكي فقط، بلا معالجة دفع إلكتروني آلية).
 * - يتضمن `placeOrder`/`onReviewWrite` بمنطق مختلف تماماً عن
 *   push-server/api/order.js و review.js الحاليين — نشرهما سوياً يعني
 *   مصدرَي حقيقة متعارضين لنفس البيانات (مخزون، طلبات، تقييمات).
 * - يعتمد على `functions.config()` لأسرار (Stripe/Cloudinary/Gmail) قد
 *   لا تكون مضبوطة أصلاً على المشروع الحالي — نشر بلا ضبطها يفشل فوراً
 *   وقد يعطّل نشر بقية الدوال معه.
 *
 * قبل أي نشر مستقبلي: راجع كل دالة هنا مقابل push-server/ الحالي، احذف
 * ما يتعارض، وأعد ربط firebase.json عمداً فقط عندئذ.
 *
 * خوادم Cloud Functions لتطبيق العربية للكريستال (نص تاريخي أصلي أدناه)
 *
 * النشر:
 *   1) firebase login
 *   2) firebase functions:config:set stripe.secret_key="sk_test_..."
 *   3) firebase functions:config:set cloudinary.cloud_name="..." cloudinary.api_key="..." cloudinary.api_secret="..."
 *   4) firebase functions:config:set gmail.user="you@gmail.com" gmail.app_password="xxxxxxxxxxxxxxxx"
 *      (App Password من إعدادات أمان حساب Google، وليس كلمة مرور Gmail العادية)
 *   5) cd functions && npm install
 *   6) firebase deploy --only functions
 */
const functions = require('firebase-functions/v1');
const admin = require('firebase-admin');
const crypto = require('crypto');
const nodemailer = require('nodemailer');
const stripe = require('stripe')(functions.config().stripe.secret_key);

admin.initializeApp();

const db = () => admin.firestore();

/**
 * مساعد: كتابة إشعار جديد في مجموعة notifications
 * (تُلتقط تلقائياً بواسطة sendPushNotification لترسل FCM)
 */
async function writeNotification({
  title,
  body,
  target = 'all',
  targetId = null,
  type = 'general',
  linkId = null,
}) {
  await db().collection('notifications').add({
    title,
    body,
    target,
    targetId: targetId || null,
    type,
    linkId: linkId || null,
    createdAt: new Date().toISOString(),
  });
}

/**
 * إرسال إشعار FCM تلقائياً عند إضافة إشعار جديد في مجموعة notifications
 * (مثل: إشعار منتج جديد من لوحة الإدارة أو إشعار يدوي)
 * - يقرأ رموز الأجهزة (fcmTokens) من مستندات المستخدمين
 * - يدعم الاستهداف: all (الجميع) / user (مستخدم محدد) / admin (المدراء فقط)
 * - أعد النشر بعد التعديل: firebase deploy --only functions
 */
exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snapshot) => {
    const data = snapshot.data() || {};
    const title = data.title || 'العربية للكريستال';
    const body = data.body || '';
    const target = data.target || 'all';
    const targetId = data.targetId || null;

    // جمع رموز الأجهزة من جميع المستخدمين
    const usersSnapshot = await db().collection('users').get();
    const tokens = [];
    for (const userDoc of usersSnapshot.docs) {
      const user = userDoc.data() || {};
      if (target === 'user' && userDoc.id !== targetId) continue;
      if (target === 'admin' && user.role !== 'admin') continue;
      const fcmTokens = user.fcmTokens;
      if (Array.isArray(fcmTokens)) {
        for (const token of fcmTokens) {
          if (typeof token === 'string' && token.length > 0) {
            tokens.push(token);
          }
        }
      }
    }

    if (tokens.length === 0) {
      console.log('لا توجد أجهزة مسجلة لإرسال الإشعار');
      return null;
    }

    const uniqueTokens = [...new Set(tokens)];
    const message = {
      notification: { title, body },
      data: {
        type: data.type || 'general',
        linkId: data.linkId || '',
      },
      android: { priority: 'high' },
    };

    // FCM يقبل 500 رمز كحد أقصى لكل استدعاء
    const batchSize = 500;
    for (let i = 0; i < uniqueTokens.length; i += batchSize) {
      const chunk = uniqueTokens.slice(i, i + batchSize);
      try {
        const response = await admin.messaging().sendEachForMulticast({
          tokens: chunk,
          ...message,
        });
        console.log(
          `تم إرسال الإشعار: ${response.successCount} نجحت، ${response.failureCount} فشلت`,
        );
      } catch (error) {
        console.error('فشل إرسال الإشعار:', error.message);
      }
    }

    return null;
  });

/** أسماء حالات الطلب بالعربية لعرضها في الإشعار */
const ORDER_STATUS_LABELS = {
  pending: 'قيد الانتظار',
  confirmed: 'مؤكد',
  processing: 'قيد التجهيز',
  shipped: 'تم الشحن',
  outForDelivery: 'خرج للتوصيل',
  delivered: 'تم التوصيل',
  cancelled: 'ملغي',
  returned: 'مرتجع',
};

/**
 * إشعار المدير عند وصول طلب جديد
 * - يكتب إشعاراً target=admin فيُنشئ sendPushNotification ليرسل للمدراء فقط
 */
exports.onNewOrder = functions.firestore
  .document('orders/{orderId}')
  .onCreate(async (snapshot) => {
    const order = snapshot.data() || {};
    const total = Number(order.total) || 0;
    const itemCount = Array.isArray(order.items) ? order.items.length : 0;
    await writeNotification({
      title: 'طلب جديد',
      body: `وصل طلب جديد بقيمة ${total.toFixed(2)} ر.س (${itemCount} صنف)`,
      target: 'admin',
      type: 'order',
      linkId: snapshot.id,
    });
    return null;
  });

/**
 * إشعار العميل عند تغيير حالة طلبه
 * - يُرسل فقط لصاحب الطلب (target=user مع targetId=userId)
 */
exports.onOrderUpdate = functions.firestore
  .document('orders/{orderId}')
  .onUpdate(async (change) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const prevStatus = before.status;
    const newStatus = after.status;
    if (!prevStatus || prevStatus === newStatus || !newStatus) return null;
    if (!after.userId) return null;

    const label = ORDER_STATUS_LABELS[newStatus] || newStatus;
    await writeNotification({
      title: 'تحديث حالة طلبك',
      body: `طلبك رقم #${change.after.id} أصبح: ${label}`,
      target: 'user',
      targetId: after.userId,
      type: 'order',
      linkId: change.after.id,
    });

    // كسب نقاط الولاء عند التسليم فقط (وليس عند الإنشاء) لمنع كسب نقاط
    // من طلبات أُلغيت لاحقاً — نقطة واحدة عن كل 10 ر.س من إجمالي الطلب
    if (newStatus === 'delivered' && !(Number(after.pointsEarned) > 0)) {
      const earned = Math.floor((Number(after.total) || 0) / POINTS_EARN_DIVISOR);
      if (earned > 0) {
        await db().runTransaction(async (tx) => {
          tx.update(db().collection('users').doc(after.userId), {
            points: admin.firestore.FieldValue.increment(earned),
          });
          tx.set(db().collection('pointsLedger').doc(), {
            userId: after.userId,
            type: 'earned',
            points: earned,
            orderId: change.after.id,
            createdAt: new Date().toISOString(),
          });
          tx.update(change.after.ref, { pointsEarned: earned });
        });
      }
    }
    return null;
  });

/**
 * إشعار "منتج عاد متوفر" عند تغير المخزون من 0 إلى ما يزيد عنه
 */
exports.onProductBackInStock = functions.firestore
  .document('products/{productId}')
  .onUpdate(async (change) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};
    const prevStock = Number(before.stock) || 0;
    const newStock = Number(after.stock) || 0;
    if (prevStock > 0 || newStock <= 0) return null;

    const name = after.name || 'منتج';
    await writeNotification({
      title: 'منتج عاد للمخزون',
      body: `${name} — متوفر مجدداً في العربية للكريستال`,
      target: 'all',
      type: 'product',
      linkId: change.after.id,
    });
    return null;
  });

// ---------------------------------------------------------------------------
// تسعير وإنشاء الطلبات — كل الحسابات تُعاد من الخادم اعتماداً على بيانات
// المنتجات/الكوبونات الحقيقية في Firestore، وليس على أي رقم يرسله العميل.
// هذا يمنع تلاعب العميل بالسعر/الإجمالي المرسل لبوابة الدفع أو المحفوظ
// بالطلب.
// ---------------------------------------------------------------------------

const FREE_SHIPPING_THRESHOLD = 500;
const SHIPPING_FEE = 25;
const MAX_ORDER_ITEMS = 50;
const MAX_QUANTITY_PER_ITEM = 20;

// نقاط الولاء: نقطة واحدة تُكسَب عن كل 10 ر.س عند تسليم الطلب، وكل 10
// نقاط تساوي 1 ر.س خصم عند استخدامها في طلب جديد
const POINTS_EARN_DIVISOR = 10;
const POINTS_REDEEM_DIVISOR = 10;

/** يطابق قواعد الكوبون النقية في lib/shared/services/coupon_service.dart */
function assertCouponRules(coupon, { subtotal, productIds, categoryIds }) {
  if (coupon.isActive === false) {
    throw new functions.https.HttpsError('failed-precondition', 'هذا الكوبون معطّل');
  }
  if (coupon.expiryDate) {
    const expiry = new Date(coupon.expiryDate);
    if (!Number.isNaN(expiry.getTime()) && new Date() > expiry) {
      throw new functions.https.HttpsError('failed-precondition', 'انتهت صلاحية هذا الكوبون');
    }
  }
  if (typeof coupon.usageLimit === 'number' && (coupon.usedCount || 0) >= coupon.usageLimit) {
    throw new functions.https.HttpsError('failed-precondition', 'تم استنفاد عدد استخدامات هذا الكوبون');
  }
  const minOrderAmount = Number(coupon.minOrderAmount) || 0;
  if (subtotal < minOrderAmount) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `الحد الأدنى للطلب بهذا الكوبون ${minOrderAmount.toFixed(0)} ر.س`,
    );
  }
  const applicableProductIds = coupon.applicableProductIds || [];
  const applicableCategoryIds = coupon.applicableCategoryIds || [];
  if (applicableProductIds.length > 0 || applicableCategoryIds.length > 0) {
    const hasProduct = applicableProductIds.some((id) => productIds.includes(id));
    const hasCategory = applicableCategoryIds.some((id) => categoryIds.includes(id));
    if (!hasProduct && !hasCategory) {
      throw new functions.https.HttpsError('failed-precondition', 'هذا الكوبون لا ينطبق على منتجاتك الحالية');
    }
  }
}

/** يطابق CouponService.calculateDiscount في العميل */
function calculateCouponDiscount(coupon, subtotal) {
  switch (coupon.type) {
    case 'percentage': {
      let amount = (subtotal * (Number(coupon.discountValue) || 0)) / 100;
      if (typeof coupon.maxDiscount === 'number' && amount > coupon.maxDiscount) {
        amount = coupon.maxDiscount;
      }
      return amount;
    }
    case 'fixed': {
      const amount = Number(coupon.discountValue) || 0;
      return Math.min(Math.max(amount, 0), subtotal);
    }
    case 'freeShipping':
      return 0;
    default:
      return 0;
  }
}

/**
 * إنشاء طلب جديد — يعيد حساب الأسعار والشحن والكوبون بالكامل من الخادم،
 * يتحقق من المخزون وينقصه، ويستهلك الكوبون (إن وُجد) ضمن معاملة واحدة
 * (transaction) لضمان الاتساق تحت الحمل المتزامن.
 */
exports.placeOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول لإتمام الطلب');
  }
  const uid = context.auth.uid;

  const rawItems = Array.isArray(data && data.items) ? data.items : [];
  if (rawItems.length === 0 || rawItems.length > MAX_ORDER_ITEMS) {
    throw new functions.https.HttpsError('invalid-argument', 'سلة غير صالحة');
  }
  const requested = [];
  const seenProductIds = new Set();
  for (const raw of rawItems) {
    const productId = raw && raw.productId;
    const quantity = Number(raw && raw.quantity);
    if (typeof productId !== 'string' || productId.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'منتج غير صالح');
    }
    if (!Number.isInteger(quantity) || quantity <= 0 || quantity > MAX_QUANTITY_PER_ITEM) {
      throw new functions.https.HttpsError('invalid-argument', 'كمية غير صالحة');
    }
    if (seenProductIds.has(productId)) {
      throw new functions.https.HttpsError('invalid-argument', 'منتج مكرر بالسلة');
    }
    seenProductIds.add(productId);
    requested.push({ productId, quantity });
  }

  const paymentMethod = ['cod', 'online', 'bankTransfer'].includes(data && data.paymentMethod)
    ? data.paymentMethod
    : 'cod';
  const shippingAddress =
    typeof (data && data.shippingAddress) === 'string' && data.shippingAddress.trim()
      ? data.shippingAddress.trim().slice(0, 500)
      : null;
  const notes =
    typeof (data && data.notes) === 'string' ? data.notes.trim().slice(0, 500) : '';
  const couponCode =
    typeof (data && data.couponCode) === 'string' && data.couponCode.trim()
      ? data.couponCode.trim().toUpperCase()
      : null;
  const requestedPointsToRedeem = Number(data && data.pointsToRedeem) || 0;
  if (!Number.isInteger(requestedPointsToRedeem) || requestedPointsToRedeem < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'عدد نقاط غير صالح');
  }

  const firestore = db();
  const orderRef = firestore.collection('orders').doc();
  const userRef = firestore.collection('users').doc(uid);
  const pointsLedgerRef = firestore.collection('pointsLedger').doc();

  const order = await firestore.runTransaction(async (tx) => {
    const productRefs = requested.map((r) => firestore.collection('products').doc(r.productId));
    const [productSnaps, userSnap] = await Promise.all([
      Promise.all(productRefs.map((ref) => tx.get(ref))),
      tx.get(userRef),
    ]);

    const items = [];
    const productIds = [];
    const categoryIds = [];
    let subtotal = 0;

    for (let i = 0; i < requested.length; i++) {
      const snap = productSnaps[i];
      const { productId, quantity } = requested[i];
      if (!snap.exists) {
        throw new functions.https.HttpsError('not-found', `منتج غير موجود: ${productId}`);
      }
      const p = snap.data() || {};
      const stock = Number(p.stock) || 0;
      if (stock > 0 && quantity > stock) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          `الكمية المتوفرة من "${p.name || productId}" غير كافية`,
        );
      }
      const unitPrice = typeof p.discountPrice === 'number' ? p.discountPrice : Number(p.price) || 0;
      subtotal += unitPrice * quantity;
      productIds.push(productId);
      if (p.categoryId) categoryIds.push(p.categoryId);
      items.push({
        productId,
        name: p.name || '',
        price: Number(p.price) || 0,
        discountPrice: typeof p.discountPrice === 'number' ? p.discountPrice : null,
        image: Array.isArray(p.images) && p.images.length > 0 ? p.images[0] : '',
        quantity,
        stock,
        categoryId: p.categoryId || null,
      });
    }

    let discountAmount = 0;
    let freeShippingApplied = false;
    let couponRef = null;

    if (couponCode) {
      couponRef = firestore.collection('coupons').doc(couponCode);
      const couponSnap = await tx.get(couponRef);
      if (!couponSnap.exists) {
        throw new functions.https.HttpsError('not-found', 'كوبون غير صالح');
      }
      const coupon = couponSnap.data() || {};
      assertCouponRules(coupon, { subtotal, productIds, categoryIds });
      if (typeof coupon.perUserLimit === 'number') {
        const usedBy = Array.isArray(coupon.usedBy) ? coupon.usedBy : [];
        const usedByUser = usedBy.filter((u) => u === uid).length;
        if (usedByUser >= coupon.perUserLimit) {
          throw new functions.https.HttpsError('failed-precondition', 'لقد استخدمت هذا الكوبون مسبقاً');
        }
      }
      discountAmount = calculateCouponDiscount(coupon, subtotal);
      freeShippingApplied = coupon.type === 'freeShipping';
    }

    // استخدام نقاط الولاء: لا يتجاوز الرصيد الفعلي المخزَّن بالخادم (لا
    // نثق برصيد يرسله العميل)، ولا يتجاوز المتبقي من الإجمالي بعد خصم
    // الكوبون حتى لا يصير الإجمالي سالباً
    const availablePoints = Number((userSnap.data() || {}).points) || 0;
    const pointsToRedeem = Math.min(requestedPointsToRedeem, availablePoints);
    const remainingAfterCoupon = Math.max(0, subtotal - discountAmount);
    const maxRedeemableByAmount = Math.floor(remainingAfterCoupon * POINTS_REDEEM_DIVISOR);
    const actualPointsRedeemed = Math.min(pointsToRedeem, maxRedeemableByAmount);
    const pointsDiscount = actualPointsRedeemed / POINTS_REDEEM_DIVISOR;
    discountAmount += pointsDiscount;

    const shippingFee = subtotal >= FREE_SHIPPING_THRESHOLD || freeShippingApplied ? 0 : SHIPPING_FEE;
    const total = Math.max(0, subtotal - discountAmount + shippingFee);

    const now = new Date().toISOString();
    const orderData = {
      userId: uid,
      items,
      total,
      status: 'pending',
      paymentMethod,
      shippingAddress,
      shippingFee,
      discountAmount,
      couponCode,
      pointsRedeemed: actualPointsRedeemed,
      pointsEarned: 0,
      trackingNumber: null,
      carrier: null,
      notes,
      paymentStatus: paymentMethod === 'online' ? 'unpaid' : 'notRequired',
      createdAt: now,
      updatedAt: now,
    };
    tx.set(orderRef, orderData);

    if (actualPointsRedeemed > 0) {
      tx.update(userRef, {
        points: admin.firestore.FieldValue.increment(-actualPointsRedeemed),
      });
      tx.set(pointsLedgerRef, {
        userId: uid,
        type: 'redeemed',
        points: -actualPointsRedeemed,
        orderId: orderRef.id,
        createdAt: now,
      });
    }

    for (let i = 0; i < requested.length; i++) {
      const p = productSnaps[i].data() || {};
      const stock = Number(p.stock) || 0;
      // إنقاص المخزون فقط للمنتجات المتتبَّعة فعلياً (نفس اصطلاح العميل:
      // stock<=0 تعني "غير متتبَّع" وليس "غير متوفر")
      if (stock > 0) {
        tx.update(productRefs[i], {
          stock: admin.firestore.FieldValue.increment(-requested[i].quantity),
          soldCount: admin.firestore.FieldValue.increment(requested[i].quantity),
        });
      }
    }

    if (couponRef) {
      tx.set(
        couponRef,
        {
          usedCount: admin.firestore.FieldValue.increment(1),
          usedBy: admin.firestore.FieldValue.arrayUnion(uid),
        },
        { merge: true },
      );
    }

    return { id: orderRef.id, ...orderData };
  });

  return order;
});

/**
 * إلغاء طلب معلّق (pending وغير مدفوع) من طرف صاحبه — يستعيد المخزون
 * واستهلاك الكوبون ضمن معاملة واحدة. لا يُسمح بإلغاء طلب مدفوع أو تجاوز
 * حالة "قيد الانتظار" (يلزم عندها التواصل مع الإدارة).
 */
exports.cancelOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }
  const orderId = data && data.orderId;
  if (typeof orderId !== 'string' || orderId.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'طلب غير صالح');
  }

  const firestore = db();
  const ref = firestore.collection('orders').doc(orderId);

  await firestore.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new functions.https.HttpsError('not-found', 'الطلب غير موجود');
    }
    const order = snap.data();
    if (order.userId !== context.auth.uid) {
      throw new functions.https.HttpsError('permission-denied', 'غير مصرح');
    }
    if (order.status !== 'pending' || order.paymentStatus === 'paid') {
      throw new functions.https.HttpsError('failed-precondition', 'لا يمكن إلغاء هذا الطلب');
    }

    for (const item of order.items || []) {
      if (Number(item.stock) > 0 && item.productId) {
        tx.update(firestore.collection('products').doc(item.productId), {
          stock: admin.firestore.FieldValue.increment(item.quantity),
          soldCount: admin.firestore.FieldValue.increment(-item.quantity),
        });
      }
    }
    if (order.couponCode) {
      tx.set(
        firestore.collection('coupons').doc(order.couponCode),
        {
          usedCount: admin.firestore.FieldValue.increment(-1),
          usedBy: admin.firestore.FieldValue.arrayRemove(order.userId),
        },
        { merge: true },
      );
    }
    const pointsRedeemed = Number(order.pointsRedeemed) || 0;
    if (pointsRedeemed > 0) {
      tx.update(firestore.collection('users').doc(order.userId), {
        points: admin.firestore.FieldValue.increment(pointsRedeemed),
      });
      tx.set(firestore.collection('pointsLedger').doc(), {
        userId: order.userId,
        type: 'refunded',
        points: pointsRedeemed,
        orderId,
        createdAt: new Date().toISOString(),
      });
    }
    tx.update(ref, { status: 'cancelled', updatedAt: new Date().toISOString() });
  });

  return { ok: true };
});

/**
 * إنشاء PaymentIntent لطلب موجود مسبقاً — المبلغ يُقرأ من إجمالي الطلب
 * المحسوب على الخادم (order.total)، وليس من قيمة يرسلها العميل، حتى لا
 * يقدر أحد يدفع مبلغاً أقل من قيمة طلبه الفعلية.
 */
exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول لإتمام الدفع');
  }
  const orderId = data && data.orderId;
  if (typeof orderId !== 'string' || orderId.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'طلب غير صالح');
  }

  const firestore = db();
  const orderRef = firestore.collection('orders').doc(orderId);
  const orderSnap = await orderRef.get();
  if (!orderSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'الطلب غير موجود');
  }
  const order = orderSnap.data();
  if (order.userId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'غير مصرح');
  }
  if (order.paymentMethod !== 'online') {
    throw new functions.https.HttpsError('failed-precondition', 'هذا الطلب لا يتطلب دفعاً إلكترونياً');
  }
  if (order.paymentStatus === 'paid') {
    throw new functions.https.HttpsError('failed-precondition', 'تم دفع هذا الطلب مسبقاً');
  }

  const amount = Math.round((Number(order.total) || 0) * 100);
  if (amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'مبلغ غير صالح');
  }

  try {
    const paymentIntent = await stripe.paymentIntents.create({
      amount,
      currency: 'sar',
      automatic_payment_methods: { enabled: true },
      metadata: { userId: context.auth.uid, orderId },
    });
    await orderRef.update({ paymentIntentId: paymentIntent.id });
    return { clientSecret: paymentIntent.client_secret };
  } catch (error) {
    throw new functions.https.HttpsError('internal', `تعذر إنشاء الدفع: ${error.message}`);
  }
});

/**
 * تأكيد دفع طلب — يتحقق من حالة PaymentIntent مباشرة من Stripe (وليس من
 * ادّعاء العميل بأن الدفع نجح) قبل تعليم الطلب كمدفوع.
 */
exports.confirmOrderPayment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }
  const orderId = data && data.orderId;
  if (typeof orderId !== 'string' || orderId.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'طلب غير صالح');
  }

  const firestore = db();
  const ref = firestore.collection('orders').doc(orderId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'الطلب غير موجود');
  }
  const order = snap.data();
  if (order.userId !== context.auth.uid) {
    throw new functions.https.HttpsError('permission-denied', 'غير مصرح');
  }
  if (!order.paymentIntentId) {
    throw new functions.https.HttpsError('failed-precondition', 'لا توجد عملية دفع لهذا الطلب');
  }

  const intent = await stripe.paymentIntents.retrieve(order.paymentIntentId);
  if (intent.status !== 'succeeded') {
    throw new functions.https.HttpsError('failed-precondition', 'لم يتم تأكيد الدفع بعد');
  }

  await ref.update({
    paymentStatus: 'paid',
    status: order.status === 'pending' ? 'confirmed' : order.status,
    updatedAt: new Date().toISOString(),
  });
  return { ok: true };
});

// ---------------------------------------------------------------------------
// رفع صور موقّع (Cloudinary) — التوقيع يُحسب على الخادم بمفتاح سري لا
// يغادره أبداً، بدل الاعتماد على unsigned upload preset مكشوف بالكود
// (كان يسمح لأي شخص خارج التطبيق بالرفع المباشر لحساب Cloudinary).
// ---------------------------------------------------------------------------

exports.getCloudinarySignature = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }

  const cfg = functions.config().cloudinary || {};
  const apiKey = cfg.api_key;
  const apiSecret = cfg.api_secret;
  const cloudName = cfg.cloud_name;
  if (!apiKey || !apiSecret || !cloudName) {
    throw new functions.https.HttpsError('failed-precondition', 'إعدادات رفع الصور غير مكتملة');
  }

  const rawType = data && data.type;
  const type = rawType === 'avatar' ? 'avatar' : rawType === 'review' ? 'review' : 'product';
  let folder;
  let publicId;

  if (type === 'product') {
    const userSnap = await db().collection('users').doc(context.auth.uid).get();
    const role = (userSnap.data() || {}).role;
    if (role !== 'admin') {
      throw new functions.https.HttpsError('permission-denied', 'صلاحية الإدارة مطلوبة لرفع صور المنتجات');
    }
    const productId = data && data.productId;
    if (typeof productId !== 'string' || productId.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'معرّف منتج غير صالح');
    }
    folder = 'products';
    publicId = `p-${productId}-${Date.now()}`;
  } else if (type === 'review') {
    // صور تقييم: أي مستخدم مسجَّل يرفع لتقييمه الخاص (uid من الخادم)
    const productId = data && data.productId;
    if (typeof productId !== 'string' || productId.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'معرّف منتج غير صالح');
    }
    folder = 'reviews';
    publicId = `rv-${context.auth.uid}-${productId}-${Date.now()}`;
  } else {
    // أفاتار: كل مستخدم يرفع فقط لمجلده الخاص (uid من الخادم، ليس من العميل)
    folder = 'avatars';
    publicId = `a-${context.auth.uid}-${Date.now()}`;
  }

  const timestamp = Math.floor(Date.now() / 1000);
  const paramsToSign = `folder=${folder}&public_id=${publicId}&timestamp=${timestamp}`;
  const signature = crypto
    .createHash('sha1')
    .update(paramsToSign + apiSecret)
    .digest('hex');

  return { signature, timestamp, apiKey, cloudName, folder, publicId };
});

// ---------------------------------------------------------------------------
// طلبات الاسترداد — العميل يُنشئ الطلب مباشرة، لكن القرار الفعلي (موافقة/
// رفض) واسترداد المبلغ الحقيقي عبر Stripe يتم حصراً هنا بصلاحيات Admin
// SDK، حتى لا ينفصل تغيير حالة الطلب عن عملية الاسترداد المالي الفعلية.
// ---------------------------------------------------------------------------

exports.processRefundRequest = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }
  const adminSnap = await db().collection('users').doc(context.auth.uid).get();
  if ((adminSnap.data() || {}).role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'صلاحية الإدارة مطلوبة');
  }

  const requestId = data && data.requestId;
  const approve = (data && data.approve) === true;
  const adminNote = typeof (data && data.adminNote) === 'string' ? data.adminNote.trim().slice(0, 500) : null;
  if (typeof requestId !== 'string' || requestId.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'طلب غير صالح');
  }

  const firestore = db();
  const requestRef = firestore.collection('refundRequests').doc(requestId);
  const requestSnap = await requestRef.get();
  if (!requestSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'طلب الاسترداد غير موجود');
  }
  const refundRequest = requestSnap.data();
  if (refundRequest.status !== 'pending') {
    throw new functions.https.HttpsError('failed-precondition', 'تمت معالجة هذا الطلب مسبقاً');
  }

  const orderRef = firestore.collection('orders').doc(refundRequest.orderId);
  const orderSnap = await orderRef.get();
  const order = orderSnap.exists ? orderSnap.data() : null;

  if (approve) {
    // استرداد فعلي عبر Stripe فقط للطلبات المدفوعة إلكترونياً
    if (order && order.paymentMethod === 'online' && order.paymentStatus === 'paid' && order.paymentIntentId) {
      try {
        await stripe.refunds.create({ payment_intent: order.paymentIntentId });
      } catch (error) {
        throw new functions.https.HttpsError('internal', `تعذر تنفيذ الاسترداد عبر Stripe: ${error.message}`);
      }
    }
    if (order) {
      await orderRef.update({ status: 'returned', updatedAt: new Date().toISOString() });
    }
    await requestRef.update({
      status: 'approved',
      adminNote,
      resolvedAt: new Date().toISOString(),
    });
    await writeNotification({
      title: 'تمت الموافقة على طلب الاسترداد',
      body: `طلب الاسترداد لطلبك #${refundRequest.orderId} تمت الموافقة عليه`,
      target: 'user',
      targetId: refundRequest.userId,
      type: 'order',
      linkId: refundRequest.orderId,
    });
  } else {
    await requestRef.update({
      status: 'rejected',
      adminNote,
      resolvedAt: new Date().toISOString(),
    });
    await writeNotification({
      title: 'تم رفض طلب الاسترداد',
      body: `طلب الاسترداد لطلبك #${refundRequest.orderId} تم رفضه`,
      target: 'user',
      targetId: refundRequest.userId,
      type: 'order',
      linkId: refundRequest.orderId,
    });
  }

  return { ok: true };
});

// ---------------------------------------------------------------------------
// الدعم المباشر — إشعار الطرف الآخر عند وصول رسالة جديدة
// ---------------------------------------------------------------------------

exports.onChatMessage = functions.firestore
  .document('supportChats/{uid}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data() || {};
    const uid = context.params.uid;
    const fromAdmin = message.senderRole === 'admin';
    const text = (message.text || '').slice(0, 120);

    await writeNotification({
      title: fromAdmin ? 'رد جديد من الدعم' : 'رسالة دعم جديدة',
      body: text,
      target: fromAdmin ? 'user' : 'admin',
      targetId: fromAdmin ? uid : null,
      type: 'chat',
      linkId: uid,
    });
    return null;
  });

// ---------------------------------------------------------------------------
// تقييمات المنتجات — إعادة حساب متوسط التقييم وعدده على مستند المنتج
// تلقائياً عند أي إضافة/تعديل/حذف لتقييم، بدل الاعتماد على حساب العميل.
// ---------------------------------------------------------------------------

async function recomputeProductRating(productId) {
  const snap = await db().collection('reviews').where('productId', '==', productId).get();
  const ratings = snap.docs.map((d) => Number(d.data().rating) || 0);
  const reviewCount = ratings.length;
  const rating = reviewCount > 0 ? ratings.reduce((a, b) => a + b, 0) / reviewCount : 0;
  await db().collection('products').doc(productId).update({ rating, reviewCount });
}

exports.onReviewWrite = functions.firestore
  .document('reviews/{reviewId}')
  .onWrite(async (change) => {
    const data = change.after.exists ? change.after.data() : change.before.data();
    const productId = data && data.productId;
    if (!productId) return null;
    await recomputeProductRating(productId);
    return null;
  });

// ---------------------------------------------------------------------------
// التحقق من البريد الإلكتروني بكود رقمي (OTP) عبر Gmail — بديل عن رابط
// Firebase الافتراضي. الكود يُخزَّن ويُتحقَّق منه على الخادم فقط، ويُعلَّم
// الحساب كموثَّق (emailVerified) عبر Admin SDK بعد نجاح المطابقة.
// ---------------------------------------------------------------------------

const EMAIL_CODE_TTL_MS = 10 * 60 * 1000; // 10 دقائق
const EMAIL_CODE_COOLDOWN_MS = 60 * 1000; // دقيقة واحدة بين كل إرسال
const EMAIL_CODE_MAX_ATTEMPTS = 5;

let _mailTransporter = null;
function mailTransporter() {
  if (_mailTransporter) return _mailTransporter;
  const cfg = functions.config().gmail || {};
  if (!cfg.user || !cfg.app_password) {
    throw new functions.https.HttpsError('failed-precondition', 'إعدادات إرسال البريد غير مكتملة');
  }
  _mailTransporter = nodemailer.createTransport({
    service: 'gmail',
    auth: { user: cfg.user, pass: cfg.app_password },
  });
  return _mailTransporter;
}

/** إرسال كود تحقق من 6 أرقام إلى بريد المستخدم المسجَّل دخوله حالياً */
exports.sendEmailVerificationCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }
  const uid = context.auth.uid;
  const authUser = await admin.auth().getUser(uid);
  const email = authUser.email;
  if (!email) {
    throw new functions.https.HttpsError('failed-precondition', 'لا يوجد بريد إلكتروني مرتبط بهذا الحساب');
  }
  if (authUser.emailVerified) {
    return { ok: true, alreadyVerified: true };
  }

  const ref = db().collection('emailVerificationCodes').doc(uid);
  const existing = await ref.get();
  if (existing.exists) {
    const lastSentAt = existing.data().lastSentAt;
    const elapsed = lastSentAt ? Date.now() - new Date(lastSentAt).getTime() : Infinity;
    if (elapsed < EMAIL_CODE_COOLDOWN_MS) {
      const waitSeconds = Math.ceil((EMAIL_CODE_COOLDOWN_MS - elapsed) / 1000);
      throw new functions.https.HttpsError(
        'resource-exhausted',
        `يرجى الانتظار ${waitSeconds} ثانية قبل طلب كود جديد`,
      );
    }
  }

  const code = String(crypto.randomInt(100000, 1000000));
  const now = new Date();
  await ref.set({
    code,
    email,
    attempts: 0,
    lastSentAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + EMAIL_CODE_TTL_MS).toISOString(),
  });

  try {
    await mailTransporter().sendMail({
      from: `"العربية للكريستال" <${functions.config().gmail.user}>`,
      to: email,
      subject: 'كود تأكيد بريدك الإلكتروني - العربية للكريستال',
      text: `كود التحقق الخاص بك هو: ${code}\nصالح لمدة 10 دقائق. لا تشاركه مع أحد.`,
      html: `<div dir="rtl" style="font-family:sans-serif;text-align:center;padding:24px">
        <h2 style="color:#1A237E">العربية للكريستال</h2>
        <p>كود تأكيد بريدك الإلكتروني:</p>
        <p style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#1A237E">${code}</p>
        <p style="color:#666;font-size:13px">صالح لمدة 10 دقائق. إن لم تطلب هذا الكود تجاهل هذه الرسالة.</p>
      </div>`,
    });
  } catch (error) {
    throw new functions.https.HttpsError('internal', 'تعذر إرسال البريد الإلكتروني، حاول لاحقاً');
  }

  return { ok: true, alreadyVerified: false };
});

/** التحقق من الكود المُدخَل، وتعليم البريد موثَّقاً عند التطابق */
exports.verifyEmailCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'يجب تسجيل الدخول');
  }
  const uid = context.auth.uid;
  const submittedCode = data && data.code ? String(data.code).trim() : '';
  if (!submittedCode) {
    throw new functions.https.HttpsError('invalid-argument', 'أدخل الكود');
  }

  const ref = db().collection('emailVerificationCodes').doc(uid);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new functions.https.HttpsError('not-found', 'لم يتم إرسال كود بعد، اطلب كوداً جديداً');
  }
  const record = snap.data();

  if (new Date(record.expiresAt).getTime() < Date.now()) {
    await ref.delete();
    throw new functions.https.HttpsError('deadline-exceeded', 'انتهت صلاحية الكود، اطلب كوداً جديداً');
  }
  if ((record.attempts || 0) >= EMAIL_CODE_MAX_ATTEMPTS) {
    await ref.delete();
    throw new functions.https.HttpsError('resource-exhausted', 'محاولات كثيرة، اطلب كوداً جديداً');
  }
  if (record.code !== submittedCode) {
    const attempts = (record.attempts || 0) + 1;
    await ref.update({ attempts });
    const remaining = EMAIL_CODE_MAX_ATTEMPTS - attempts;
    throw new functions.https.HttpsError(
      'invalid-argument',
      remaining > 0 ? `كود غير صحيح، لديك ${remaining} محاولات متبقية` : 'كود غير صحيح، اطلب كوداً جديداً',
    );
  }

  await admin.auth().updateUser(uid, { emailVerified: true });
  await ref.delete();
  return { ok: true };
});
