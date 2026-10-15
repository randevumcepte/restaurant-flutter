import java.util.Properties

// İmza anahtari: android/key.properties (git'e girmez). Yoksa debug ile imzalar.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) load(keystorePropertiesFile.inputStream())
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.resteos.enjula"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications v18+ icin gerekli (java.time vb. eski Android'de).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.resteos.enjula"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Android 15/16 edge-to-edge dayatmasi dokunma koordinatlarini kaydiriyordu (ikonun altina basinca aciliyordu).
        // targetSdk 34 -> geleneksel yerlesim (durum cubugu altinda), dokunma hizali.
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // key.properties varsa release anahtariyla, yoksa debug ile imzala.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring (flutter_local_notifications zorunlulugu)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
