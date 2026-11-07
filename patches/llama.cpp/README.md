# llama.cpp Android runtimes

The upstream source-build workflow remains the default. Its version-only
`assets/bin/llama_server_manifest.json` is supported directly by app packaging
and APK verification. Official prebuilts are a separate opt-in route below.
Source builds retain Android API 28 and CPU/OpenCL/Hexagon; the optional official
Snapdragon archive instead requires API 34. Do not apply that API 34 requirement
to the source-build route. API 28 is a build target, not a guarantee of device
compatibility: source OpenCL/Hexagon builds still need the relevant Qualcomm
vendor libraries and supported hardware.

## Default: source build (OpenCL + Hexagon)

Default workflow source: **llama.cpp v0.8.0**. The bundled app version remains defined by `assets/bin/llama_server_manifest.json`; changing the workflow does not replace its native binaries.

- Preset: `CMakeUserPresets.servllama.json`. Copy it to the llama.cpp root as `CMakeUserPresets.json`.
- Optional patch: `0001-hexagon-skip-unsupported-devices.patch` (written for v0.4.1)
- Image: `ghcr.io/snapdragon-toolchain/arm64-android:v0.8`
- Build script: `build_snapdragon_android.sh`

The optional patch stops llama.cpp v0.4.1 from registering a dummy `HTP0` on SoCs below Hexagon v73, such as Snapdragon 8 Gen 1. It is disabled by default for newer upstream releases, not automatically rewritten or silently skipped if selected.

`libggml-htp-v*.so` are Hexagon ELF files. Do not strip them with the Android NDK `llvm-strip`.

Image v0.8 provides Android NDK r29, Hexagon SDK 6.7.0.0 and Hexagon Tools 21.0.04. It does not set `OPENCL_SDK_ROOT`; OpenCL headers and `libOpenCL.so` come from the NDK sysroot. `HEXAGON_SDK_ROOT` and `HEXAGON_TOOLS_ROOT` are set in the image.

Upstream enabled Hexagon v85 and switched from `toolv19` to `toolv21` in [#30854](https://github.com/ggml-org/llama.cpp/pull/30854), together with image v0.8. Using image v0.7 (SDK 6.6 / Tools 19) with that newer source can compile a target named v85 with v68 flags and fail on missing HVX intrinsics such as `Q6_Vw_equals_Vsf`. Keep the source and toolchain compatible; do not disable compiler errors or force a different DSP architecture to work around this.

The image follows upstream's [Snapdragon CI](https://github.com/ggml-org/llama.cpp/blob/master/.github/workflows/build-and-test-snapdragon.yml) and [release workflow](https://github.com/ggml-org/llama.cpp/blob/master/.github/workflows/release.yml). Upstream publishes Android Snapdragon archives with CPU, OpenCL and Hexagon support. ServLlama still builds its own bundle: its preset retains Android API 28 and runtime-selected CPU variants instead of upstream's global ARMv8.7 flags, and the build script uses static libc++ and 16 KiB Android ELF alignment.

### GitHub Actions

`.github/workflows/build-llama-server-android.yml` is the release build. Run it manually with the desired tag; the default is `v0.8.0` with **Hexagon patch** unchecked.

The job checks out that tag, optionally applies the patch, and builds in the Snapdragon image. It uploads `llama-server-<tag>-android-arm64-v8a.tar.gz`. Copy both `android/app/src/main/jniLibs/arm64-v8a/` and `assets/bin/llama_server_manifest.json` from the archive over the app tree. The bundled manifest version is `<tag>` without the patch, or `<tag>+hexagon-skip-unsupported` with it. `BUILD_INFO.json` records the source revision, image/digest, SDK paths and patch name (or `null`).

If **Hexagon patch** is selected but does not apply, the job fails. Leave it unchecked for v0.8.0 or another source version that does not match the v0.4.1 patch. Older tags may also require the toolchain documented by that tag's upstream build guide.

Packaging verifies every `build_htp_skel(vNN)` target declared by the selected source, so newer releases must include v85 while older releases need not. `tool/verify_android_bundle.py` checks all `libggml-htp-*.so` as Hexagon ELF files and verifies they remain byte-identical to the JNI originals; new DSP versions are not mistaken for Android AArch64 libraries.

### Local build

```bash
git clone https://github.com/ggml-org/llama.cpp.git ~/src/llama.cpp
cd ~/src/llama.cpp
git checkout v0.8.0
cp /path/to/patches/llama.cpp/CMakeUserPresets.servllama.json CMakeUserPresets.json

docker run --rm -u "$(id -u):$(id -g)" \
  --platform linux/amd64 \
  -e HOME=/tmp \
  -e DEST_JNI=/workspace/dist/arm64-v8a \
  --volume "$HOME/src/llama.cpp":/workspace \
  --volume /path/to/patches/llama.cpp:/opt/servllama-patches:ro \
  ghcr.io/snapdragon-toolchain/arm64-android:v0.8 \
  bash /opt/servllama-patches/build_snapdragon_android.sh /workspace
```

The script enables CPU variants, OpenCL, and Hexagon, builds llama-server and the HTP skels, strips Android ELF files, and copies the JNI whitelist to `DEST_JNI`.

### App behavior

The Flutter app runs `libllama-server.so --list-devices` with the same `LD_LIBRARY_PATH` and `ADSP_LIBRARY_PATH` as a normal start. Settings expose CPU and Hexagon. Hexagon takes a configurable offload layer count. OpenCL is still packaged, but it is hidden because Adreno results are not reliable yet. If the saved accelerator is unavailable, startup falls back to CPU.

When changing between source and official runtimes, start from a clean set of
llama-owned JNI files (libggml*, libllama*, libmtmd); preserve MNN, speech and
other app libraries. Copy the source archive JNI directory together with its
version-only manifest. Mixed source/official runtime sets are rejected.
Source APK verification compares runtime bytes with the supplied source-build
JNI files; it does not claim that custom builds are official release artifacts.

## Optional official llama.cpp v0.8.0 prebuilts

This opt-in route uses **unmodified official llama.cpp v0.8.0** artifacts.
Run the preparation command explicitly to switch from the default source route. The [v0.8.0 release](https://github.com/ggml-org/llama.cpp/releases/tag/v0.8.0)
links its binaries through [b11960](https://github.com/ggml-org/llama.cpp/releases/tag/b11960).
Both tags resolve to commit `8642541b255bfb5dc39cd351a178be09013a55d6`
(`v0.8.0` is an annotated tag; compare its peeled commit).

### Runtime variants

| Variant | Minimum Android | Packaged llama backends | Device requirement |
|---|---|---|---|
| `cpu` (default) | Android 9 / API 28 | CPU variants and upstream RPC backend | ARM64; includes the ARMv8.0 baseline |
| `snapdragon` | Android 14 / API 34 | CPU, OpenCL, Hexagon and upstream RPC backend | Compatible Qualcomm device with accessible vendor OpenCL/FastRPC libraries |

These are ARM64 APKs, not universal-ABI APKs. The runtime does not contain Vulkan.
MNN is a separate engine and its existing backend capabilities are unchanged.
The app's existing device probe/fallback remains in place: CPU-only builds have
no Hexagon accelerator. The app rejects the official v0.8.0 placeholder `HTP0`
when probe diagnostics say the DSP is below v73 or the architecture query failed;
this app-side guard replaces the old source patch without changing official bytes.
The guard and CPU fallback are covered by parser fixtures, not real-device NPU tests.
OpenCL remains hidden in the current UI. An unavailable
saved accelerator falls back to CPU, but that **cannot** rescue a Snapdragon
binary that cannot link its mandatory `libOpenCL.so` vendor dependency. Use the
CPU variant on non-Qualcomm devices and for general compatibility.

The minimum SDK values above were checked in the downloaded ELF Android notes:
CPU API 28 and Snapdragon API 34, both built upstream with NDK r29 (14206865).
The Gradle manifest minimum SDK follows the selected runtime, so Snapdragon APKs
cannot install on unsupported Android 9–13. All packaged AArch64 LOAD segments
are 16 KiB aligned. Hexagon DSP files use their upstream DSP alignment, not the
Android host page-size rule; v73, v75, v79, v81 and v85 are included.

### Download and prepare

Download the desired archive from the official release (no third-party mirror):

```bash
# General ARM64 CPU runtime (default).
curl -fL https://github.com/ggml-org/llama.cpp/releases/download/b11960/llama-b11960-bin-android-arm64.tar.gz \
  -o /tmp/llama-b11960-bin-android-arm64.tar.gz
python3 tool/prepare_llama_runtime.py /tmp/llama-b11960-bin-android-arm64.tar.gz --variant cpu

# Or the Qualcomm-specific runtime. This replaces ONLY llama-owned JNI files.
curl -fL https://github.com/ggml-org/llama.cpp/releases/download/b11960/llama-b11960-bin-android-arm64-snapdragon.tar.gz \
  -o /tmp/llama-b11960-bin-android-arm64-snapdragon.tar.gz
python3 tool/prepare_llama_runtime.py /tmp/llama-b11960-bin-android-arm64-snapdragon.tar.gz --variant snapdragon
```

The script verifies the pinned archive SHA-256 **before writing**:

- CPU: `77d9f19fad41d6d8efbc29bcc1c1ab60a605018564cfc32203892eb1973ba4b9`
- Snapdragon: `b5f404eee508c2429d136cc95bcae2c6e1556612175fe3ccc223ac147a1a17cf`

Only allowlisted regular files are read from the archive; native code is never
executed by the installer. The server is renamed to `libllama-server.so` for
Android's native-library packaging, **without changing its bytes**. Unused
command-line tools are omitted. The script checks ELF architecture, alignment
and runtime dependency closure, removes stale llama files when switching
variants, preserves unrelated app/speech/MNN libraries, and writes provenance
and per-file hashes to `assets/bin/llama_server_manifest.json`. The upstream MIT
license is bundled as `assets/licenses/llama-cpp-native.txt`.

Gradle verifies the source native hashes before packaging and skips stripping
these official files. Do not manually strip, patch, or mix binaries from the
two variants. No legacy Hexagon source patch is applied to either official
v0.8.0 archive.

### Build and verify

Prepare the existing speech/MNN prerequisites separately, then use the pinned
Flutter 3.35.2 toolchain:

```bash
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
python3 -m unittest discover -s tool -p test_prepare_llama_runtime.py -v
flutter build apk --release --target-platform android-arm64
python3 tool/verify_android_bundle.py build/app/outputs/flutter-apk/app-release.apk
```

Copy the APK **and its runtime manifest** before switching variants and building
again. Use descriptive names such as `servllama-v0.8.0-cpu-arm64.apk` and
`servllama-v0.8.0-snapdragon-arm64.apk`; the app identifier is shared, so they
replace one another rather than install side by side. To audit a previously
saved variant, supply `--llama-manifest PATH` and, for unchanged DSP source
checks, `--jni-dir PATH` containing that variant's original JNI files.

The APK audit checks the embedded manifest/license, exact upstream native
hashes, conditional backend requirements, runtime dependency closure, ARM64
architecture, host alignment, speech manifest hash and unchanged DSP kernels.
APK signing and Android manifest version/minSdk should also be checked with
`apksigner`/`aapt`. A packaging pass does not establish device execution,
Qualcomm driver compatibility, model inference or performance. The upstream
native files have not been rebuilt or claimed to be hardware-qualified here.

