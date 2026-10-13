import java.util.Properties

// The ByeByeSleep watch app (Wear OS): live heart rate for the phone's
// "Get your heart going" challenge. Same application id and signing key as
// the phone app — the Wearable Data Layer only connects such pairs.
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "com.mrgardener.byebyesleep.wear"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.mrgardener.byebyesleep"
        minSdk = 30
        targetSdk = 35
        versionCode = (project.findProperty("watchVersionCode") as String?)?.toInt() ?: 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        getByName("debug") {
            storeFile = file("../app/shared-debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (!keystoreProperties.isEmpty) {
            create("release") {
                storeFile = file("../app/" + keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("com.google.android.gms:play-services-wearable:19.0.0")
}
