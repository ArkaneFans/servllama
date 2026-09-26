# llama.cpp Snapdragon backends (OpenCL + Hexagon)

Pinned source: **llama.cpp v0.4.1**

- Preset: `CMakeUserPresets.servllama.json`. Copy it to the llama.cpp root as `CMakeUserPresets.json`.
- Patch: `0001-hexagon-skip-unsupported-devices.patch`
- Image: `ghcr.io/snapdragon-toolchain/arm64-android:v0.7`
- Build script: `build_snapdragon_android.sh`

The patch stops llama.cpp from registering a dummy `HTP0` on SoCs below Hexagon v73, such as Snapdragon 8 Gen 1. `--list-devices` then lists only real devices.

`libggml-htp-v*.so` are Hexagon ELF files. Do not strip them with the Android NDK `llvm-strip`.

Image v0.7 does not set `OPENCL_SDK_ROOT`. OpenCL headers and `libOpenCL.so` come from the NDK sysroot. `HEXAGON_SDK_ROOT` and `HEXAGON_TOOLS_ROOT` are set in the image.

## GitHub Actions

`.github/workflows/build-llama-server-android.yml` is the release build. Run it manually with tag `v0.4.1`.

The job checks out that tag, applies this patch, and builds in the Snapdragon image. It uploads `llama-server-<tag>-android-arm64-v8a.tar.gz`. Copy `android/app/src/main/jniLibs/arm64-v8a/` from the archive over the app tree. The bundled manifest version is `<tag>+hexagon-skip-unsupported`.

The patch is mandatory. If it does not apply, the job fails. It is written for v0.4.1.

## Local build

```bash
git clone https://github.com/ggml-org/llama.cpp.git ~/src/llama.cpp
cd ~/src/llama.cpp
git checkout v0.4.1
git apply --check /path/to/patches/llama.cpp/0001-hexagon-skip-unsupported-devices.patch
git apply /path/to/patches/llama.cpp/0001-hexagon-skip-unsupported-devices.patch
cp /path/to/patches/llama.cpp/CMakeUserPresets.servllama.json CMakeUserPresets.json

docker run --rm -u "$(id -u):$(id -g)" \
  --platform linux/amd64 \
  -e HOME=/tmp \
  -e DEST_JNI=/workspace/dist/arm64-v8a \
  --volume "$HOME/src/llama.cpp":/workspace \
  --volume /path/to/patches/llama.cpp:/opt/servllama-patches:ro \
  ghcr.io/snapdragon-toolchain/arm64-android:v0.7 \
  bash /opt/servllama-patches/build_snapdragon_android.sh /workspace
```

The script enables CPU variants, OpenCL, and Hexagon, builds llama-server and the HTP skels, strips Android ELF files, and copies the JNI whitelist to `DEST_JNI`.

## App behavior

The Flutter app runs `libllama-server.so --list-devices` with the same `LD_LIBRARY_PATH` and `ADSP_LIBRARY_PATH` as a normal start. Settings expose CPU and Hexagon. Hexagon takes a configurable offload layer count. OpenCL is still packaged, but it is hidden because Adreno results are not reliable yet. If the saved accelerator is unavailable, startup falls back to CPU.
