# llama.cpp Snapdragon backends (OpenCL + Hexagon)

Pinned tag: **v0.4.1**

Patch: `0001-hexagon-skip-unsupported-devices.patch`

This patch stops llama.cpp from registering a dummy `HTP0` GPU on SoCs below Hexagon v73 (Snapdragon 8 Gen 1 and similar). `--list-devices` then only reports real devices.

## WSL2 build

Environment used for ServLlama:

- Ubuntu-22.04 in WSL2
- `docker.io` 29.1.3
- Image: `ghcr.io/snapdragon-toolchain/arm64-android:v0.7`
- Preset: `example/snapdragon/CMakeUserPresets.servllama.json` copied to llama.cpp as `CMakeUserPresets.json`

```bash
git clone https://github.com/ggml-org/llama.cpp.git ~/src/llama.cpp
cd ~/src/llama.cpp
git checkout v0.4.1
git apply --check /path/to/0001-hexagon-skip-unsupported-devices.patch
git apply /path/to/0001-hexagon-skip-unsupported-devices.patch
cp /path/to/CMakeUserPresets.servllama.json ~/src/llama.cpp/CMakeUserPresets.json

docker run --rm -u "$(id -u):$(id -g)" \
  --volume "$HOME/src/llama.cpp":/workspace \
  --platform linux/amd64 \
  ghcr.io/snapdragon-toolchain/arm64-android:v0.7 \
  bash -lc 'cd /workspace && cmake --preset arm64-android-servllama-release -B build-snapdragon && cmake --build build-snapdragon -j "$(nproc)" && cmake --install build-snapdragon --prefix pkg-snapdragon/llama.cpp'
```

Do not NDK-strip `libggml-htp-v*.so`.

Package into the app:

```bash
python patches/llama.cpp/package_jni_libs.py \
  /path/to/pkg-snapdragon/llama.cpp \
  android/app/src/main/jniLibs/arm64-v8a
```

Then set `assets/bin/llama_server_manifest.json` `version` to `v0.4.1+hexagon-skip-unsupported`.

## App behavior

The Flutter app runs `libllama-server.so --list-devices` with the same `LD_LIBRARY_PATH` / `ADSP_LIBRARY_PATH` as a normal start. Settings expose CPU / GPU / NPU. GPU and NPU take a configurable offload layer count. If the saved accelerator is unavailable, startup falls back to CPU.
