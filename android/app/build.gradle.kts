import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play 스토어 업로드 키. android/key.properties (Git 제외)에서 읽는다.
// 만드는 방법: tools/create_upload_key.ps1
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) load(FileInputStream(keystorePropertiesFile))
}
val hasUploadKey = keystorePropertiesFile.exists()

android {
    namespace = "com.pitchcoach.pitch_coach"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Play 스토어 앱 ID — 스토어에 올린 뒤에는 바꿀 수 없다.
        applicationId = "com.pitchcoach.pitch_coach"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // pubspec.yaml의 version (1.0.0+1 → versionName 1.0.0, versionCode 1)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // 업로드 키가 있으면 그것으로 서명(스토어 제출용), 없으면 debug 키(개인 설치용).
            signingConfig = if (hasUploadKey) signingConfigs.getByName("upload") else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
