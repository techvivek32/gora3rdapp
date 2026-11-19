# ─────────────────────────────────────────────────────────────────────────────
# R8 keep rules for the release build.
#
# Why this file exists: Play Console reported "DEX code optimization is below
# our threshold — Obfuscation (2%)", with a Feb 2027 deadline. The cause was
# that `isMinifyEnabled` was false, so R8 never ran at all and every class in
# the DEX kept its real name. Turning R8 on is the fix; this file is what stops
# it from renaming or deleting the classes that are only ever looked up by
# name at runtime, which R8 cannot see.
#
# Note on Flutter: almost all of this app's own code is Dart, compiled AOT into
# libapp.so. R8 never touches it. What lives in the DEX is the Flutter Android
# embedding, the plugins, and Firebase — so these rules are all about plugins.
#
# Flutter's own rules (keeping FlutterPlugin implementations, -dontwarn for the
# embedding and android.**) are applied automatically by the Flutter Gradle
# plugin from flutter_proguard_rules.pro. They are not repeated here.
# ─────────────────────────────────────────────────────────────────────────────

# ── Razorpay ────────────────────────────────────────────────────────────────
# The checkout SDK drives its WebView through @JavascriptInterface methods and
# calls back into the app by *method name* (onPaymentSuccess/onPaymentError),
# neither of which R8 can trace. These are Razorpay's own published rules.
# Without them the payment sheet opens and the result callback never fires —
# the user is charged and the app never learns about it.
-keepattributes JavascriptInterface
-keepattributes *Annotation*
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepclasseswithmembers class * {
  public void onPayment*(...);
}
# Razorpay asks for this specifically: inlining breaks its callback dispatch.
-optimizations !method/inlining/*

# ── Gson ────────────────────────────────────────────────────────────────────
# Used by several plugins (notifications, Play services) to deserialise models
# via reflection. R8 strips generic signatures by default, which makes Gson
# fall back to Object and silently leave every field null.
-keepattributes Signature
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# ── flutter_overlay_window ──────────────────────────────────────────────────
# OverlayService is named as a string in AndroidManifest.xml and the overlay's
# Dart entry point is reached through it. AGP's manifest keep rules cover the
# service class itself; this keeps the plugin's constants and the engine cache
# tag ("myCachedEngine") that MainActivity looks the overlay engine up by.
-keep class flutter.overlay.window.flutter_overlay_window.** { *; }

# ── Firebase Messaging background handler ───────────────────────────────────
# The background FCM isolate is started by name from the native side. Keeping
# the embedding's background-execution plumbing stops R8 removing the path that
# wakes the booking-alert isolate when the app is not running.
-keep class io.flutter.plugins.firebase.messaging.** { *; }
-keep class io.flutter.embedding.engine.FlutterJNI { *; }

# ── Play Core / in-app update ───────────────────────────────────────────────
# The Play Core split-install classes are referenced by the deferred-components
# code in the Flutter embedding even when the app does not use them.
-dontwarn com.google.android.play.core.**

# ── Misc ────────────────────────────────────────────────────────────────────
# Keep line numbers so Play Console and Crashlytics can map an obfuscated
# stack trace back to source. SourceFile is renamed rather than kept, which is
# what lets the mapping file do the work without leaking real file names.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Enum valueOf() is reached reflectively by several plugins' method channels.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable CREATOR fields are read reflectively by the framework.
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}
