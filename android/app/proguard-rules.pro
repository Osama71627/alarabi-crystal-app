# قواعد ProGuard/R8 لنسخة الإصدار (release) — تمنع تكسير مكتبات تعتمد
# على الانعكاس (reflection) عند تصغير/تعتيم الكود.

# Flutter engine (احتياط إضافي فوق قواعد Flutter الافتراضية المدمجة)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Stripe
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**

# Gson (يُستخدم بواسطة بعض الإضافات لتسلسل JSON عبر الانعكاس)
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Kotlin metadata (تتطلبها بعض مكتبات AndroidX/Firebase وقت التشغيل)
-keepclassmembers class kotlin.Metadata { *; }
-dontwarn kotlin.**
