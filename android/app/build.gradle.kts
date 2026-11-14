import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeyProperties = keystorePropertiesFile.exists()

if (hasKeyProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val configuredStoreFile = keystoreProperties.getProperty("storeFile")
val keystoreFile = if (configuredStoreFile != null) {
    val f = file(configuredStoreFile)
    if (f.exists()) f else rootProject.file(configuredStoreFile)
} else {
    file("plantoday.jks")
}
val hasValidKeyProperties = hasKeyProperties && keystoreFile.exists()

android {
    namespace = "com.plantoday.flutter.plantoday_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.plantoday.flutter.plantoday_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.add("arm64-v8a")
        }
    }

    signingConfigs {
        create("release") {
            if (hasValidKeyProperties) {
                storeFile = keystoreFile
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            } else {
                val storeFilePath = System.getenv("MYAPP_UPLOAD_STORE_FILE")
                if (!storeFilePath.isNullOrEmpty()) {
                    val storeFileObj = file(storeFilePath)
                    if (storeFileObj.exists()) {
                        storeFile = storeFileObj
                        storePassword = System.getenv("MYAPP_UPLOAD_STORE_PASSWORD")
                        keyAlias = System.getenv("MYAPP_UPLOAD_KEY_ALIAS")
                        keyPassword = System.getenv("MYAPP_UPLOAD_KEY_PASSWORD")
                    }
                }
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            signingConfig = if (releaseSigning.storeFile != null && releaseSigning.storeFile!!.exists()) {
                releaseSigning
            } else {
                signingConfigs.getByName("debug")
            }
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
