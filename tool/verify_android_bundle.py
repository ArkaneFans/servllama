"""Audit a built ServLlama APK, without installing it or loading native code.

Checks ABI, ELF LOAD alignment, the pinned speech hash and source-built or optional official llama.cpp,
runtime dependencies, the embedded manifest/license and unchanged Hexagon DSP
kernels. Android manifest version, signing and device execution remain separate.
"""

import argparse
import hashlib
import json
from pathlib import Path
import struct
import re
import sys
import zipfile

from prepare_llama_runtime import (
    ANDROID_SYSTEM, BUILD, COMMIT, DSP_NAMES, VARIANTS, VERSION,
    elf_metadata, runtime_library,
)


ROOT = Path(__file__).resolve().parents[1]
REQUIRED = {
    "libflutter.so",
    "libllama-server.so",
    "libMNN.so",
    "libmnn_engine_jni.so",
    "libsherpa-onnx-c-api.so",
    "libonnxruntime.so",
    "libservllama_crispasr.so",
    "libsqlite3.so",
}


SOURCE_CORE = {
    "libggml.so", "libggml-base.so", "libggml-opencl.so", "libggml-hexagon.so",
    "libllama.so", "libllama-common.so", "libllama-server-impl.so",
    "libllama-server.so", "libmtmd.so",
}
SOURCE_DSP = {f"libggml-htp-v{version}.so" for version in (73, 75, 79, 81)}


def runtime_distribution(manifest):
    """Only the exact legacy source shape may omit official provenance."""
    if not isinstance(manifest, dict):
        raise ValueError("llama.cpp manifest must be an object")
    if set(manifest) == {"version"}:
        if not isinstance(manifest.get("version"), str) or not manifest["version"].strip():
            raise ValueError("Source runtime requires a nonempty version")
        return "source"
    if manifest.get("distribution", "official") != "official":
        raise ValueError("Invalid source runtime manifest or unknown distribution")
    # Rich legacy official manifests remain supported, but partial official
    # metadata never falls back to the source route.
    required = {"schemaVersion", "version", "variant", "source", "artifact",
                "abi", "minSdk", "backends", "externalDependencies", "license", "libraries"}
    if not required.issubset(manifest) or manifest["schemaVersion"] != 1:
        raise ValueError("Incomplete official runtime manifest")
    if (manifest["abi"] != "arm64-v8a" or not isinstance(manifest["variant"], str) or
            manifest["variant"] not in VARIANTS):
        raise ValueError("Invalid official runtime ABI or variant")
    if (not all(isinstance(manifest[key], dict) for key in ("source", "artifact", "license")) or
            not isinstance(manifest["libraries"], list) or
            not all(isinstance(record, dict) for record in manifest["libraries"])):
        raise ValueError("Invalid official runtime provenance records")
    return "official"


def source_runtime_spec(jni_directory):
    names = {path.name for path in jni_directory.iterdir()
             if path.is_file() and runtime_library(path.name)}
    cpu = {name for name in names if re.fullmatch(r"libggml-cpu-[A-Za-z0-9_.-]+\.so", name)}
    dsp = {name for name in names if re.fullmatch(r"libggml-htp-v[0-9]+\.so", name)}
    required = SOURCE_CORE | SOURCE_DSP | cpu | dsp
    errors = []
    if not cpu:
        errors.append("Source runtime is missing CPU variants")
    if names - required:
        errors.append(f"Unexpected/mixed source runtime libraries: {sorted(names - required)}")
    if required - names:
        errors.append(f"Missing source runtime libraries: {sorted(required - names)}")
    return {"required": required, "minSdk": 28,
            "external": {"libOpenCL.so", "libcdsprpc.so"}}, errors


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def elf_loads(data):
    if data[:4] != b"\x7fELF" or data[5:6] != b"\x01":
        raise ValueError("Expected a little-endian ELF")
    machine = struct.unpack_from("<H", data, 18)[0]
    if data[4] == 2:
        table = struct.unpack_from("<Q", data, 32)[0]
        stride, count = struct.unpack_from("<HH", data, 54)
        header_format = "<IIQQQQQQ"
        offset_index, address_index, align_index = 2, 3, 7
    elif data[4] == 1:
        table = struct.unpack_from("<I", data, 28)[0]
        stride, count = struct.unpack_from("<HH", data, 42)
        header_format = "<IIIIIIII"
        offset_index, address_index, align_index = 1, 2, 7
    else:
        raise ValueError("Unsupported ELF class")
    if stride < struct.calcsize(header_format) or count == 0:
        raise ValueError("Invalid program header table")
    loads = []
    for index in range(count):
        header = struct.unpack_from(header_format, data, table + index * stride)
        if header[0] == 1:
            loads.append({
                "offset": header[offset_index],
                "address": header[address_index],
                "alignment": header[align_index],
            })
    if not loads:
        raise ValueError("ELF has no LOAD segments")
    return machine, loads


def audit(apk, manifest_path, jni_directory, llama_manifest_path=None):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    pinned = manifest["library"]
    llama_manifest_path = llama_manifest_path or ROOT / "assets/bin/llama_server_manifest.json"
    llama = json.loads(llama_manifest_path.read_text(encoding="utf-8"))
    distribution = runtime_distribution(llama)
    variant = llama["variant"] if distribution == "official" else "source-snapdragon"
    libraries = []
    if distribution == "official":
        spec = VARIANTS[variant]
        llama_records = {record["name"]: record for record in llama["libraries"]}
        errors = []
    else:
        spec, errors = source_runtime_spec(jni_directory)
        llama_records = {}
    if distribution == "official" and (llama["version"] != VERSION or llama["source"]["commit"] != COMMIT or
            llama["source"]["tag"] != VERSION or llama["source"]["buildTag"] != BUILD or
            llama["minSdk"] != spec["minSdk"] or
            llama["artifact"]["sha256"] != spec["sha256"] or
            llama["artifact"].get("unmodified") is not True):
        errors.append("llama.cpp provenance does not match the pinned official release")
    if distribution == "official" and (set(llama_records) != spec["required"] or
                                        len(llama_records) != len(llama["libraries"])):
        errors.append("Runtime manifest libraries do not match the selected official variant")
    with zipfile.ZipFile(apk) as archive:
        asset = "assets/flutter_assets/assets/bin/llama_server_manifest.json"
        try:
            if json.loads(archive.read(asset)) != llama:
                errors.append("Embedded llama.cpp manifest differs from build manifest")
            if distribution == "official":
                license_data = archive.read("assets/flutter_assets/" + llama["license"]["asset"])
                if hashlib.sha256(license_data).hexdigest() != llama["license"]["sha256"]:
                    errors.append("Embedded llama.cpp license differs from official license")
        except (KeyError, ValueError) as error:
            errors.append(f"Missing or invalid llama.cpp manifest/license: {error}")
        entries = [entry for entry in archive.infolist()
                   if entry.filename.startswith("lib/") and not entry.is_dir()]
        names = [entry.filename for entry in entries]
        abis = sorted({name.split("/")[1] for name in names})
        if abis != ["arm64-v8a"]:
            errors.append(f"Unexpected APK ABIs: {abis}")
        if len(names) != len(set(names)):
            errors.append("Duplicate native ZIP entries")
        packaged_names = {name.split("/")[-1] for name in names}
        missing = (REQUIRED | spec["required"]) - packaged_names
        if missing:
            errors.append(f"Missing libraries: {sorted(missing)}")
        extra_runtime = {name for name in packaged_names if runtime_library(name)} - spec["required"]
        if extra_runtime:
            errors.append(f"Unexpected/mixed llama.cpp libraries: {sorted(extra_runtime)}")
        for entry in entries:
            name = entry.filename.split("/")[-1]
            data = archive.read(entry)
            digest = hashlib.sha256(data).hexdigest()
            record = {"path": entry.filename, "bytes": len(data), "sha256": digest,
                      "zip_compression": entry.compress_type}
            try:
                machine, loads = elf_loads(data)
                record.update(machine=machine, load_segments=loads)
                if name.startswith("libggml-htp-") and name.endswith(".so"):
                    original = jni_directory / name
                    if machine != 164:
                        errors.append(f"{name}: expected Hexagon ELF")
                    if not original.is_file() or sha256_file(original) != digest:
                        errors.append(f"{name}: missing source or DSP bytes changed")
                    record["dsp_source_matches"] = original.is_file() and (
                        sha256_file(original) == digest)
                else:
                    if machine != 183:
                        errors.append(f"{name}: expected AArch64 ELF")
                    if any(load["alignment"] < 16384 or
                           (load["address"] - load["offset"]) % 16384
                           for load in loads):
                        errors.append(f"{name}: LOAD segments are not 16 KiB aligned")
                if name == pinned["name"] and (
                        digest != pinned["sha256"] or len(data) != pinned["bytes"]):
                    errors.append(f"{name}: differs from pinned build manifest")
                if name in {"libMNN.so", "libmnn_engine_jni.so"}:
                    # Hosted plugin natives retain generic ELF/dependency checks;
                    # this does not assert custom-build or official provenance.
                    dynamic = elf_metadata(data)
                    record["needed"] = dynamic["needed"]
                    unresolved = set(dynamic["needed"]) - (
                        packaged_names | ANDROID_SYSTEM | {"libz.so"})
                    if unresolved:
                        errors.append(f"{name}: unresolved MNN dependencies: {sorted(unresolved)}")
                if distribution == "source" and runtime_library(name):
                    original = jni_directory / name
                    matches = original.is_file() and not original.is_symlink() and (
                        sha256_file(original) == digest)
                    record["source_build_matches"] = matches
                    if not matches:
                        errors.append(f"{name}: differs from supplied source-build JNI original")
                    dynamic = elf_metadata(data)
                    record["needed"] = dynamic["needed"]
                    dsp = bool(re.fullmatch(r"libggml-htp-v[0-9]+\.so", name))
                    if not dsp and dynamic.get("androidApi", 28) > 28:
                        errors.append(f"{name}: source runtime requires Android API above 28")
                    allowed = {"libc.so", "libgcc.so"} if dsp else (
                        spec["required"] | ANDROID_SYSTEM | {"libz.so"} | spec["external"])
                    unresolved = set(dynamic["needed"]) - allowed
                    if unresolved:
                        errors.append(f"{name}: unresolved source dependencies: {sorted(unresolved)}")
                if name in llama_records:
                    expected = llama_records[name]
                    matches = digest == expected["sha256"] and len(data) == expected["bytes"]
                    record["official_source_matches"] = matches
                    if not matches:
                        errors.append(f"{name}: differs from unmodified official runtime")
                    dynamic = elf_metadata(data)
                    record["needed"] = dynamic["needed"]
                    allowed = {"libc.so", "libgcc.so"} if name in DSP_NAMES else (
                        spec["required"] | ANDROID_SYSTEM | spec["external"])
                    unresolved = set(dynamic["needed"]) - allowed
                    if unresolved:
                        errors.append(f"{name}: unresolved dependencies: {sorted(unresolved)}")
            except (IndexError, ValueError, struct.error) as error:
                errors.append(f"{name}: {error}")
            libraries.append(record)
    return {"apk": str(apk), "bytes": apk.stat().st_size,
            "sha256": sha256_file(apk), "abis": abis,
            "llama_version": llama["version"], "llama_variant": variant,
            "llama_distribution": distribution,
            "runtime_min_sdk": spec["minSdk"],
            "external_dependencies": sorted(spec["external"]),
            "libraries": libraries, "errors": errors, "passed": not errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--manifest", type=Path,
                        default=ROOT / "native/speech/android-arm64-v8a.json")
    parser.add_argument("--jni-dir", type=Path,
                        default=ROOT / "android/app/src/main/jniLibs/arm64-v8a")
    parser.add_argument("--llama-manifest", type=Path,
                        default=ROOT / "assets/bin/llama_server_manifest.json")
    args = parser.parse_args()
    try:
        report = audit(args.apk, args.manifest, args.jni_dir, args.llama_manifest)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        parser.exit(2, f"Cannot audit APK: {error}\n")
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
