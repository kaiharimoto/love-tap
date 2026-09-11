import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The key that signs a release, read from a file that is not in this repository and never will be.
//
// `android/key.properties` holds four lines — storeFile, storePassword, keyAlias, keyPassword —
// and is gitignored along with every keystore extension. Nothing here has a default: a release
// built without that file is signed with the debug key, which Android will install and which is
// not a release, so the build says so loudly rather than producing something that looks shippable
// and is not. docs/PHONES.md says how to make the key.
val keyFile = rootProject.file("key.properties")
val key = Properties().apply { if (keyFile.exists()) keyFile.inputStream().use { load(it) } }
val signedForReal = keyFile.exists() &&
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all { key.getProperty(it) != null }

// Said at configuration time, from the top level, where it reaches the terminal. Inside the
// buildTypes block `logger.lifecycle` was swallowed — the APK came out signed `CN=Android Debug`
// and nothing anywhere said so, which is exactly the failure this line exists to prevent.
if (!signedForReal) {
    println("")
    println("  -- This release will be signed with the DEBUG key -------------------------")
    println("  android/key.properties is absent, so `flutter build apk --release` produces")
    println("  an APK signed `CN=Android Debug`. It installs on a phone and it is not a")
    println("  release: a build signed with a real key cannot replace it without")
    println("  uninstalling, which takes the log with it. docs/PHONES.md says how to make")
    println("  the key. tools/check/apk.py reads the signature off whatever was built.")
    println("  ---------------------------------------------------------------------------")
    println("")
}

android {
    namespace = "io.lovetap.desk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.lovetap.desk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signedForReal) {
            create("release") {
                storeFile = rootProject.file(key.getProperty("storeFile"))
                storePassword = key.getProperty("storePassword")
                keyAlias = key.getProperty("keyAlias")
                keyPassword = key.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (signedForReal) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Installable, and not a release. Said out loud at build time rather than left to
                // be discovered on a phone: an APK signed with the debug key cannot be updated by
                // one signed with a real key without uninstalling first, which takes the log with
                // it, and that is a thing to find out before two people have a year in it.
                signingConfig = signingConfigs.getByName("debug")
            }
            // The log lives in the app's own storage and is the only copy on this phone. Nothing
            // here backs it up anywhere, so nothing here may hand it to Google's backup service.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // NotificationCompat, ContextCompat and the permission request: the standing line and the
    // pocket both go through these, and nothing else is pulled in for them.
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter {
    source = "../.."
}
