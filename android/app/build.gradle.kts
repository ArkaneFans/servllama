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

val llamaRuntimeManifest = rootProject.file("../assets/bin/llama_server_manifest.json")
val llamaRuntime = JsonSlurper().parse(llamaRuntimeManifest) as Map<*, *>
// The upstream source workflow intentionally emits only {"version": "..."}.
// Do not downgrade an incomplete official manifest to this legacy source route.
val llamaSourceRuntime = llamaRuntime.keys == setOf("version") &&
    (llamaRuntime["version"] as? String)?.isNotBlank() == true
val llamaMinSdk = if (llamaSourceRuntime) 28 else {
    check(llamaRuntime["distribution"] == null || llamaRuntime["distribution"] == "official") {
        "Unknown llama runtime distribution; use the source workflow or official preparation tool."
    }
    val requiredFields = setOf("schemaVersion", "version", "variant", "source", "artifact",
        "abi", "minSdk", "backends", "externalDependencies", "license", "libraries")
    check(llamaRuntime.keys.containsAll(requiredFields) && llamaRuntime["schemaVersion"] == 1 &&
        listOf("source", "artifact", "license").all { llamaRuntime[it] is Map<*, *> } &&
        llamaRuntime["libraries"] is List<*>) { "Incomplete official llama runtime manifest" }
    val variant = llamaRuntime["variant"] as? String
    check(variant == "cpu" || variant == "snapdragon") { "Invalid official llama runtime variant" }
    val expectedApi = if (variant == "cpu") 28 else 34
    check((llamaRuntime["minSdk"] as? Number)?.toInt() == expectedApi) {
        "Official llama runtime minimum SDK does not match its variant"
    }
    expectedApi
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
        // Source builds target API 28; optional official Snapdragon binaries target API 34.
        minSdk = maxOf(28, llamaMinSdk)
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            // llama-server is executed as a child process, so the libraries
            // must exist as real files in nativeLibraryDir.
            useLegacyPackaging = true
            // Preserve source-runtime output and optional pinned official bytes unchanged.
            // This also prevents the NDK from stripping Hexagon DSP ELFs.
            keepDebugSymbols += setOf(
                "**/libggml*.so", "**/libllama*.so", "**/libmtmd.so",
            )
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

val verifyLlamaNative by tasks.registering {
    val directory = file("src/main/jniLibs/arm64-v8a")
    inputs.file(llamaRuntimeManifest)
    inputs.dir(directory)
    doLast {
        val metadata = JsonSlurper().parse(llamaRuntimeManifest) as Map<*, *>
        val core = setOf(
            "libggml.so", "libggml-base.so", "libggml-opencl.so", "libggml-hexagon.so",
            "libllama.so", "libllama-common.so", "libllama-server-impl.so",
            "libllama-server.so", "libmtmd.so",
        )
        val nativeNames = directory.listFiles()?.filter { it.isFile }?.map { it.name }?.toSet()
            ?: emptySet()
        val runtimeNames = nativeNames.filter {
            it.matches(Regex("lib(?:ggml(?:[-.][A-Za-z0-9_.-]+)?|llama(?:-[A-Za-z0-9_.-]+)?|mtmd)\\.so"))
        }.toSet()
        if (llamaSourceRuntime) {
            val required = core + setOf(73, 75, 79, 81).map { "libggml-htp-v$it.so" }
            check(nativeNames.containsAll(required)) { "Missing source-built llama/OpenCL/Hexagon libraries" }
            check(runtimeNames.any { it.startsWith("libggml-cpu-") }) { "Missing source-built CPU variants" }
            check(runtimeNames.all { it in core || it.startsWith("libggml-cpu-") ||
                it.matches(Regex("libggml-htp-v[0-9]+\\.so")) }) {
                "Mixed source/official llama libraries; remove stale runtime files before copying the source bundle."
            }
            runtimeNames.forEach { name ->
                val header = ByteArray(20)
                directory.resolve(name).inputStream().use { check(it.read(header) == header.size) { "Truncated $name" } }
                check(header[0] == 0x7f.toByte() && header[1] == 'E'.code.toByte() &&
                    header[2] == 'L'.code.toByte() && header[3] == 'F'.code.toByte() && header[5] == 1.toByte()) {
                    "Invalid ELF library: $name"
                }
                val machine = (header[18].toInt() and 0xff) or ((header[19].toInt() and 0xff) shl 8)
                check(machine == if (name.startsWith("libggml-htp-")) 164 else 183) { "Wrong ELF ABI: $name" }
            }
        } else {
            val variant = metadata["variant"] as String
            val source = metadata["source"] as? Map<*, *> ?: error("Missing official source provenance")
            val artifact = metadata["artifact"] as? Map<*, *> ?: error("Missing official artifact provenance")
            val archiveHash = if (variant == "cpu") {
                "77d9f19fad41d6d8efbc29bcc1c1ab60a605018564cfc32203892eb1973ba4b9"
            } else {
                "b5f404eee508c2429d136cc95bcae2c6e1556612175fe3ccc223ac147a1a17cf"
            }
            check(metadata["version"] == "v0.8.0" && metadata["abi"] == "arm64-v8a" &&
                source["tag"] == "v0.8.0" && source["buildTag"] == "b11960" &&
                source["commit"] == "8642541b255bfb5dc39cd351a178be09013a55d6" &&
                artifact["sha256"] == archiveHash && artifact["unmodified"] == true) {
                "Official llama runtime provenance does not match the pinned release"
            }
            val common = core - setOf("libggml-opencl.so", "libggml-hexagon.so") + "libggml-rpc.so"
            val required = if (variant == "cpu") {
                common + listOf("8.0_1", "8.2_1", "8.2_2", "8.6_1", "9.0_1", "9.2_1", "9.2_2")
                    .map { "libggml-cpu-android_armv$it.so" }
            } else {
                common + setOf("libggml-cpu.so", "libggml-opencl.so", "libggml-hexagon.so") +
                    setOf(73, 75, 79, 81, 85).map { "libggml-htp-v$it.so" }
            }
            val libraries = metadata["libraries"] as? List<*> ?: error("Missing official native hashes")
            val records = libraries.map { it as? Map<*, *> ?: error("Invalid official native record") }
            check(records.map { it["name"] }.toSet() == required && records.size == required.size &&
                runtimeNames == required) { "Missing or mixed official llama runtime libraries" }
            records.forEach { record ->
                val name = record["name"] as String
                val library = directory.resolve(name)
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
                check(actual == record["sha256"] && library.length() == (record["bytes"] as? Number)?.toLong()) {
                    "$name differs from the official runtime manifest."
                }
            }
        }
    }
}
tasks.named("preBuild").configure { dependsOn(verifyLlamaNative) }
