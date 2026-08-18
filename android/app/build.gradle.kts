plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.File
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun resolveStoreFile(raw: String): File {
    val path = raw.trim()
    val absolute = File(path)
    if (absolute.isAbsolute) return absolute
    val fromAndroidRoot = rootProject.file(path)
    if (fromAndroidRoot.exists()) return fromAndroidRoot
    return file(path)
}

android {
    namespace = "app.atl.scanme"
    compileSdk = maxOf(flutter.compileSdkVersion, 35)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.atl.scanme"
        minSdk = maxOf(flutter.minSdkVersion, 21)
        // Play: edge-to-edge enforced when targeting 35+; keep explicit.
        targetSdk = maxOf(flutter.targetSdkVersion, 35)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storePassword = keystoreProperties["storePassword"] as String
                storeFile = resolveStoreFile(keystoreProperties["storeFile"] as String)
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // EdgeToEdge.enable() lives on androidx.activity (not ktx).
    implementation("androidx.activity:activity:1.10.1")
    implementation("androidx.activity:activity-ktx:1.10.1")
}

flutter {
    source = "../.."
}
