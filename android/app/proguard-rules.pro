# ScanMe release ProGuard / R8
# Prefer Flutter + plugin consumer rules; avoid blanket -keep of entire SDKs
# (that tanks Play Console shrink / obfuscation rates).

# ML Kit Document Scanner (JNI / reflection)
-keep class com.google.mlkit.vision.documentscanner.** { *; }
-keep class com.google.mlkit.common.** { *; }
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# Unused Play Core split APIs referenced by some Flutter tooling
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**

# Coroutines (plugins)
-dontwarn kotlinx.coroutines.**
