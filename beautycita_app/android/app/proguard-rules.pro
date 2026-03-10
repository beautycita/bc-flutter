# ── Flutter ──
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# ── Stripe ──
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.**
-keep class com.stripe.android.** { *; }

# ── Firebase ──
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── Google Sign-In ──
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ── Supabase / GoTrue / Realtime (OkHttp + Ktor under the hood) ──
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# ── Geolocator ──
-keep class com.baseflow.geolocator.** { *; }

# ── Mobile Scanner (MLKit) ──
-keep class com.google.mlkit.** { *; }

# ── Local Auth (Biometric) ──
-keep class androidx.biometric.** { *; }

# ── Flutter Secure Storage ──
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# ── Video Player / ExoPlayer ──
-dontwarn com.google.android.exoplayer2.**
-keep class com.google.android.exoplayer2.** { *; }

# ── Kotlin serialization (used by various plugins) ──
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class kotlinx.serialization.** { *** Companion; }

# ── Play Core (deferred components, referenced by Flutter engine) ──
-dontwarn com.google.android.play.core.**

# ── General Android ──
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
