import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

private val signingProperties = Properties().also { properties ->
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.isFile) {
        FileInputStream(propertiesFile).use(properties::load)
    }
}

private fun signingValue(environmentName: String, propertyName: String): String? =
    System.getenv(environmentName)?.takeIf(String::isNotBlank)
        ?: signingProperties.getProperty(propertyName)?.takeIf(String::isNotBlank)

private val releaseStoreFilePath = signingValue("MELODIZE_KEYSTORE_FILE", "storeFile")
private val releaseStorePassword = signingValue("MELODIZE_KEYSTORE_PASSWORD", "storePassword")
private val releaseKeyAlias = signingValue("MELODIZE_KEY_ALIAS", "keyAlias")
private val releaseKeyPassword = signingValue("MELODIZE_KEY_PASSWORD", "keyPassword")
private val releaseStoreFile = releaseStoreFilePath?.let(rootProject::file)
private val hasReleaseSigning = listOf(
    releaseStoreFilePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() } &&
    releaseStoreFile?.isFile == true &&
    releaseStoreFile.canRead()

android {
    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    namespace = "com.hiby.music"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.hiby.music"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Keep debug builds usable for development, but never silently ship
            // a debug-signed release artifact. The task-graph guard below fails
            // any release build when production credentials are unavailable.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    if (!hasReleaseSigning && allTasks.any { task ->
        task.project == project &&
            task.name.contains("release", ignoreCase = true)
    }) {
        throw GradleException(
            "Production signing is required for release builds. Configure " +
                "android/key.properties or MELODIZE_KEYSTORE_FILE, " +
                "MELODIZE_KEYSTORE_PASSWORD, MELODIZE_KEY_ALIAS, and " +
                "MELODIZE_KEY_PASSWORD; also verify the keystore file exists.",
        )
    }
}

flutter {
    source = "../.."
}
