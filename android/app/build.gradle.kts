import java.util.Properties
import java.security.MessageDigest
import groovy.json.JsonSlurper

// Load release keystore values from android/key.properties when available.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.arkanefans.servllama"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.arkanefans.servllama"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 28
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            // llama-server is executed as a child process, so the libraries
            // must exist as real files in nativeLibraryDir.
            useLegacyPackaging = true
            // DSP kernels are Hexagon ELFs; the Android NDK must not strip them.
            keepDebugSymbols += "**/libggml-htp-*.so"
        }
        resources {
            excludes += setOf(
                "META-INF/INDEX.LIST",
                "META-INF/io.netty.versions.properties",
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE",
                "META-INF/MANIFEST.MF",
            )
        }
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties["storeFile"] as String?
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
            }
            storePassword = keystoreProperties["storePassword"] as String?
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
        }
    }

    buildTypes {
        configureEach {
            // Flutter 3.35 sets build-type ABI defaults, which override the
            // defaultConfig filter. All ServLlama engines require arm64.
            ndk.abiFilters.clear()
            ndk.abiFilters += "arm64-v8a"
        }
        release {
            // Falls back to debug signing until android/key.properties is configured.
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

val verifySpeechNative by tasks.registering {
    val manifest = rootProject.file("../native/speech/android-arm64-v8a.json")
    val library = file("src/main/jniLibs/arm64-v8a/libservllama_crispasr.so")
    inputs.files(manifest, library)
    doLast {
        check(library.isFile && manifest.isFile) {
            "Build the pinned CrispASR library with tool/build_speech_native.ps1 before packaging."
        }
        val metadata = JsonSlurper().parse(manifest) as Map<*, *>
        val expected = metadata["library"] as Map<*, *>
        val digest = MessageDigest.getInstance("SHA-256")
        library.inputStream().use { stream ->
            val buffer = ByteArray(1024 * 1024)
            while (true) {
                val count = stream.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        val actual = digest.digest().joinToString("") { "%02x".format(it.toInt() and 0xff) }
        check(actual == expected["sha256"]) {
            "CrispASR binary and build manifest disagree. Rebuild the pinned speech bundle."
        }
    }
}
tasks.named("preBuild").configure { dependsOn(verifySpeechNative) }
