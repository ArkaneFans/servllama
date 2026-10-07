"""Audit a built ServLlama APK, without installing it or loading native code.

Checks ABI, ELF LOAD alignment, the pinned CrispASR hash and unchanged Hexagon
DSP kernels. Signing, manifest version and device execution need separate checks.
"""

import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
import zipfile


ROOT = Path(__file__).resolve().parents[1]
DSP_NAMES = {f"libggml-htp-v{version}.so" for version in (73, 75, 79, 81)}
REQUIRED = DSP_NAMES | {
    "libflutter.so",
    "libllama-server.so",
    "libMNN.so",
    "libmnn_engine_jni.so",
    "libsherpa-onnx-c-api.so",
    "libonnxruntime.so",
    "libservllama_crispasr.so",
    "libsqlite3.so",
}


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


def audit(apk, manifest_path, jni_directory):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
    pinned = manifest["library"]
    errors, libraries = [], []
    with zipfile.ZipFile(apk) as archive:
        entries = [entry for entry in archive.infolist()
                   if entry.filename.startswith("lib/") and not entry.is_dir()]
        names = [entry.filename for entry in entries]
        abis = sorted({name.split("/")[1] for name in names})
        if abis != ["arm64-v8a"]:
            errors.append(f"Unexpected APK ABIs: {abis}")
        if len(names) != len(set(names)):
            errors.append("Duplicate native ZIP entries")
        missing = REQUIRED - {name.split("/")[-1] for name in names}
        if missing:
            errors.append(f"Missing libraries: {sorted(missing)}")
        for entry in entries:
            name = entry.filename.split("/")[-1]
            data = archive.read(entry)
            digest = hashlib.sha256(data).hexdigest()
            record = {"path": entry.filename, "bytes": len(data), "sha256": digest,
                      "zip_compression": entry.compress_type}
            try:
                machine, loads = elf_loads(data)
                record.update(machine=machine, load_segments=loads)
                if name in DSP_NAMES:
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
            except (IndexError, ValueError, struct.error) as error:
                errors.append(f"{name}: {error}")
            libraries.append(record)
    return {"apk": str(apk), "bytes": apk.stat().st_size,
            "sha256": sha256_file(apk), "abis": abis,
            "libraries": libraries, "errors": errors, "passed": not errors}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--manifest", type=Path,
                        default=ROOT / "native/speech/android-arm64-v8a.json")
    parser.add_argument("--jni-dir", type=Path,
                        default=ROOT / "android/app/src/main/jniLibs/arm64-v8a")
    args = parser.parse_args()
    try:
        report = audit(args.apk, args.manifest, args.jni_dir)
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
        parser.exit(2, f"Cannot audit APK: {error}\n")
    print(json.dumps(report, indent=2))
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
