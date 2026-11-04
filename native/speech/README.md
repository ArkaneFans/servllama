# Android speech bundle

The application requires `libservllama_crispasr.so` in
`android/app/src/main/jniLibs/arm64-v8a/`. Native binaries and source caches are
ignored by Git; `android-arm64-v8a.json` records the exact source and binary hash
checked by the Android `preBuild` task.

Install Android NDK `27.0.12077973` and SDK CMake `3.22.1` after accepting the
applicable Android SDK license. Then, from the repository root:

```sh
python3 tool/build_speech_native.py --android-sdk /path/to/android-sdk --jobs 6
```

The existing PowerShell entry point, `tool/build_speech_native.ps1`, remains
available for Windows. The Python entry point also supports Linux and macOS
and never installs SDK packages or accepts licenses automatically.

Both recipes use CrispASR `0.8.37` at commit
`2165cb64633cc8fed8e04c6002332809860b245e`, the pinned ggml and c2pa-audio
submodules, and `upstream-paths.patch`. They use a static C++ runtime, disable
OpenMP, retain the native C2PA signer, isolate exports to `crispasr_*`, target
Android API 28 / arm64-v8a, and require 16 KiB-compatible ELF load alignment.
No model weights are downloaded. Rebuilding updates the manifest's binary
size and SHA-256; do not copy a checksum from a different build.

Portable verification-helper tests:

```sh
python3 -m unittest discover -s tool -p test_build_speech_native.py -v
```

Symbol, dependency, and alignment verification does not establish on-device
ASR/TTS correctness. Test those functions separately with the intended model
weights and hardware.
