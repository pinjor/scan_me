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

# Play Pre-launch: keep EdgeToEdge.enable() recognizable after R8
# (obfuscated names look like b.a0.b and the checker misses the call).
-keep class androidx.activity.EdgeToEdge { *; }
-keepclassmembers class androidx.activity.EdgeToEdge {
    public static *** enable(...);
}
-keep class app.atl.scanme.MainActivity { *; }
-keep class app.atl.scanme.PlayEdgeToEdge { *; }
