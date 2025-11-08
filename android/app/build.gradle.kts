plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin") // her zaman en sonda olmalı
}

import java.util.Properties
import java.io.FileInputStream

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ogrencimnerede.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString() 
    }

    defaultConfig {
        applicationId = "com.ogrencimnerede.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = 11
        versionName = "1.0.11"
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        getByName("debug") {
            signingConfig = signingConfigs.getByName("release") // ✅ Debug da imzalı olur
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🔹 Java 8/11 API desteği
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // 🔹 Multidex
    implementation("androidx.multidex:multidex:2.0.1")

    // 🔹 Firebase BOM (tek sürüm yönetimi)
    implementation(platform("com.google.firebase:firebase-bom:33.3.0"))

    // 🔹 Firebase servisleri
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")
}
