#!/usr/bin/env python3
"""Build the pinned Android speech bundle on Linux, macOS, or Windows.

Equivalent to build_speech_native.ps1, using an already installed Android SDK.
This script does not install SDK packages or accept Android SDK licenses.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys


PIN = "2165cb64633cc8fed8e04c6002332809860b245e"
SUBMODULES = {
    "ggml": "2f5a80d258c46e6ac8eee95f1328c0f58376d7ee",
    "third_party/c2pa-audio": "e40329b83f16f67bb5ddc7bb13ae18de0a9376fc",
}
ALLOWED_NEEDED = {
    "libc.so", "libm.so", "libdl.so", "liblog.so", "libandroid.so", "libmediandk.so",
}
REQUIRED_SYMBOLS = {
    "crispasr_session_open", "crispasr_session_transcribe",
    "crispasr_session_synthesize", "crispasr_c2pa_sign",
}


def run(*args, cwd=None):
    subprocess.run([str(arg) for arg in args], cwd=cwd, check=True)


def output(*args, cwd=None):
    return subprocess.check_output(
        [str(arg) for arg in args], cwd=cwd, text=True,
    ).strip()


def validate_native(dynamic, segments, symbols):
    needed = re.findall(r"Shared library: \[(.+?)\]", dynamic)
    unexpected = set(needed) - ALLOWED_NEEDED
    if unexpected:
        raise RuntimeError(f"Unpackaged or conflicting dependencies: {sorted(unexpected)}")
    loads = [line for line in segments.splitlines() if re.match(r"\s*LOAD\s", line)]
    if not loads or any(int(line.split()[-1], 16) < 16384 for line in loads):
        raise RuntimeError("Speech library is not at least 16 KiB aligned")
    defined = {line.split()[-1].split("@")[0] for line in symbols.splitlines() if line.split()}
    missing = REQUIRED_SYMBOLS - defined
    if missing:
        raise RuntimeError(f"Missing speech ABI: {sorted(missing)}")
    unexpected_symbols = {
        name for name in defined
        if not name.startswith("crispasr_") and name != "SERVLLAMA_CRISPASR_1"
    }
    if unexpected_symbols:
        raise RuntimeError(f"Unisolated native symbols: {sorted(unexpected_symbols)}")
    return needed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--android-sdk", default=os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT"))
    parser.add_argument("--ndk-version", default="27.0.12077973")
    parser.add_argument("--cmake-version", default="3.22.1")
    parser.add_argument("--jobs", type=int, default=6)
    args = parser.parse_args()
    if not args.android_sdk:
        parser.error("Pass --android-sdk or set ANDROID_HOME")
    root = Path(__file__).resolve().parent.parent
    sdk = Path(args.android_sdk).resolve()
    source = root / "native-cache/CrispASR"
    build = root / "native-cache/build-crisp-android"
    ndk = sdk / "ndk" / args.ndk_version
    host = {"Linux": "linux-x86_64", "Darwin": "darwin-x86_64", "Windows": "windows-x86_64"}.get(platform.system())
    if host is None:
        raise RuntimeError(f"Unsupported build host: {platform.system()}")
    suffix = ".exe" if platform.system() == "Windows" else ""
    llvm = ndk / "toolchains/llvm/prebuilt" / host / "bin"
    cmake = sdk / "cmake" / args.cmake_version / "bin" / f"cmake{suffix}"
    ninja = cmake.with_name(f"ninja{suffix}")
    # Fail before fetching sources if the user has not installed the toolchain.
    for required in (cmake, ninja, llvm / f"llvm-strip{suffix}", ndk / "build/cmake/android.toolchain.cmake"):
        if not required.is_file():
            raise RuntimeError(f"Required SDK tool is not installed: {required}")
    if not (source / ".git").exists():
        source.parent.mkdir(parents=True, exist_ok=True)
        run("git", "clone", "--no-checkout", "https://github.com/CrispStrobe/CrispASR.git", source)
        # The pinned commit may no longer be reachable from current branch tips.
        run("git", "fetch", "origin", PIN, cwd=source)
        run("git", "checkout", "--detach", PIN, cwd=source)
    actual = output("git", "rev-parse", "HEAD", cwd=source)
    if actual != PIN:
        raise RuntimeError(f"CrispASR cache must be at {PIN}, found {actual}")
    run("git", "submodule", "update", "--init", *SUBMODULES, cwd=source)
    for submodule, expected in SUBMODULES.items():
        actual = output("git", "rev-parse", "HEAD", cwd=source / submodule)
        if actual != expected:
            raise RuntimeError(f"Incorrect {submodule} revision: {actual}")
    patch = root / "native/speech/upstream-paths.patch"
    check = subprocess.run(
        ["git", "apply", "--ignore-space-change", "--check", str(patch)],
        cwd=source, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    if check.returncode == 0:
        run("git", "apply", "--ignore-space-change", patch, cwd=source)
    else:
        run("git", "apply", "--ignore-space-change", "--reverse", "--check", patch, cwd=source)
    run(
        cmake, "-S", root / "native/speech", "-B", build, "-G", "Ninja",
        f"-DCMAKE_MAKE_PROGRAM={ninja}",
        f"-DCMAKE_TOOLCHAIN_FILE={ndk / 'build/cmake/android.toolchain.cmake'}",
        f"-DCRISPASR_SOURCE={source}", "-DANDROID_ABI=arm64-v8a",
        "-DANDROID_PLATFORM=android-28", "-DANDROID_STL=c++_static",
        "-DCMAKE_BUILD_TYPE=Release",
    )
    run(cmake, "--build", build, "--target", "crispasr-lib", "-j", args.jobs)
    destination = root / "android/app/src/main/jniLibs/arm64-v8a"
    destination.mkdir(parents=True, exist_ok=True)
    library = destination / "libservllama_crispasr.so"
    shutil.copy2(build / "crispasr/src/libservllama_crispasr.so", library)
    run(llvm / f"llvm-strip{suffix}", "--strip-unneeded", library)
    needed = validate_native(
        output(llvm / f"llvm-readelf{suffix}", "-d", library),
        output(llvm / f"llvm-readelf{suffix}", "-lW", library),
        output(llvm / f"llvm-nm{suffix}", "-D", "--defined-only", library),
    )
    metadata = {
        "schemaVersion": 1,
        "source": {
            "repository": "https://github.com/CrispStrobe/CrispASR",
            "commit": PIN, "version": "0.8.37", "ggml": SUBMODULES["ggml"],
            "c2pa": SUBMODULES["third_party/c2pa-audio"],
        },
        "build": {
            "abi": "arm64-v8a", "ndk": args.ndk_version, "minSdk": 28,
            "stl": "c++_static", "openmp": False, "pageSize": 16384,
            "exportedSymbols": "crispasr_*", "c2pa": True,
        },
        "library": {
            "name": library.name, "bytes": library.stat().st_size,
            "sha256": hashlib.sha256(library.read_bytes()).hexdigest(), "needed": needed,
        },
    }
    (root / "native/speech/android-arm64-v8a.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8",
    )
    print(f"Built and verified {library}")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
