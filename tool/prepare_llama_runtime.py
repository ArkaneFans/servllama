"""Install a checksum-pinned, unmodified official llama.cpp Android runtime.

Downloads are deliberately separate: this command accepts a local official
archive, validates it before writing, and never executes its native code.
"""

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import tarfile


ROOT = Path(__file__).resolve().parents[1]
VERSION = "v0.8.0"
BUILD = "b11960"
COMMIT = "8642541b255bfb5dc39cd351a178be09013a55d6"
BASE_URL = f"https://github.com/ggml-org/llama.cpp/releases/download/{BUILD}"
CORE = {
    "libllama-server.so", "libllama-server-impl.so", "libllama-common.so",
    "libllama.so", "libmtmd.so", "libggml.so", "libggml-base.so", "libggml-rpc.so",
}
CPU_VARIANTS = {
    f"libggml-cpu-android_armv{version}.so"
    for version in ("8.0_1", "8.2_1", "8.2_2", "8.6_1", "9.0_1", "9.2_1", "9.2_2")
}
DSP_NAMES = {f"libggml-htp-v{version}.so" for version in (73, 75, 79, 81, 85)}
VARIANTS = {
    "cpu": {
        "archive": "llama-b11960-bin-android-arm64.tar.gz",
        "sha256": "77d9f19fad41d6d8efbc29bcc1c1ab60a605018564cfc32203892eb1973ba4b9",
        "backends": ["cpu", "rpc"],
        "minSdk": 28,
        "required": CORE | CPU_VARIANTS,
        "external": set(),
    },
    "snapdragon": {
        "archive": "llama-b11960-bin-android-arm64-snapdragon.tar.gz",
        "sha256": "b5f404eee508c2429d136cc95bcae2c6e1556612175fe3ccc223ac147a1a17cf",
        "backends": ["cpu", "opencl", "hexagon", "rpc"],
        "minSdk": 34,
        "required": CORE | DSP_NAMES | {
            "libggml-cpu.so", "libggml-opencl.so", "libggml-hexagon.so",
        },
        "external": {"libOpenCL.so"},
    },
}
ANDROID_SYSTEM = {"libc.so", "libm.so", "libdl.so", "liblog.so", "libandroid.so"}


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def runtime_library(name):
    return bool(re.fullmatch(r"lib(?:ggml(?:[-.][A-Za-z0-9_.-]+)?|llama(?:-[A-Za-z0-9_.-]+)?|mtmd)\.so", name))


def elf_metadata(data):
    """Read ELF headers and DT_NEEDED without loading code or external tools."""
    if data[:4] != b"\x7fELF" or data[5:6] != b"\x01":
        raise ValueError("Expected little-endian ELF")
    machine = struct.unpack_from("<H", data, 18)[0]
    if data[4] == 2:
        table = struct.unpack_from("<Q", data, 32)[0]
        stride, count = struct.unpack_from("<HH", data, 54)
        header_format, dynamic_format = "<IIQQQQQQ", "<qQ"
        offset_index, address_index, size_index, align_index = 2, 3, 5, 7
    elif data[4] == 1:
        table = struct.unpack_from("<I", data, 28)[0]
        stride, count = struct.unpack_from("<HH", data, 42)
        header_format, dynamic_format = "<IIIIIIII", "<iI"
        offset_index, address_index, size_index, align_index = 1, 2, 4, 7
    else:
        raise ValueError("Unsupported ELF class")
    if stride < struct.calcsize(header_format) or count == 0:
        raise ValueError("Invalid program header table")
    segments = [struct.unpack_from(header_format, data, table + i * stride)
                for i in range(count)]
    loads = [{"offset": h[offset_index], "address": h[address_index],
              "alignment": h[align_index]} for h in segments if h[0] == 1]
    if not loads:
        raise ValueError("ELF has no LOAD segments")
    needed_offsets, string_address = [], None
    for header in segments:
        if header[0] != 2:
            continue
        start, size = header[offset_index], header[size_index]
        for offset in range(start, start + size, struct.calcsize(dynamic_format)):
            tag, value = struct.unpack_from(dynamic_format, data, offset)
            if tag == 0:
                break
            if tag == 1:
                needed_offsets.append(value)
            elif tag == 5:
                string_address = value
    needed = []
    if needed_offsets:
        if string_address is None:
            raise ValueError("Missing ELF dynamic string table")
        string_offset = None
        for header in segments:
            start = header[address_index]
            if header[0] == 1 and start <= string_address < start + header[size_index]:
                string_offset = header[offset_index] + string_address - start
                break
        if string_offset is None:
            raise ValueError("ELF dynamic string table is outside a LOAD segment")
        for offset in needed_offsets:
            start = string_offset + offset
            end = data.find(b"\0", start)
            if end < 0:
                raise ValueError("Unterminated ELF dependency")
            needed.append(data[start:end].decode("ascii"))
    result = {"machine": machine, "load_segments": loads, "needed": needed}
    for header in segments:
        if header[0] != 4:
            continue
        offset, end = header[offset_index], header[offset_index] + header[size_index]
        while offset + 12 <= end:
            namesz, descsz, kind = struct.unpack_from("<III", data, offset)
            offset += 12
            name = data[offset:offset + namesz].rstrip(b"\0")
            offset += (namesz + 3) & ~3
            description = data[offset:offset + descsz]
            offset += (descsz + 3) & ~3
            if name == b"Android" and kind == 1 and descsz >= 4:
                result["androidApi"] = struct.unpack_from("<I", description)[0]
                if descsz >= 132:
                    result["ndkVersion"] = description[4:68].split(b"\0")[0].decode("ascii")
                    result["ndkBuild"] = description[68:132].split(b"\0")[0].decode("ascii")
    return result


def read_payload(archive_path, variant):
    """Read only regular, allowlisted files; never extract archive paths."""
    spec = VARIANTS[variant]
    payload = {}
    with tarfile.open(archive_path, "r:gz") as archive:
        for member in archive:
            path = PurePosixPath(member.name)
            if path.is_absolute() or ".." in path.parts:
                raise ValueError(f"Unsafe archive member: {member.name}")
            if not path.parts or path.parts[0] != f"llama-{BUILD}":
                raise ValueError(f"Unexpected archive root: {member.name}")
            name = "libllama-server.so" if path.name == "llama-server" else path.name
            if name not in spec["required"] and name != "LICENSE":
                continue
            if not member.isfile():
                raise ValueError(f"Runtime file must be a regular file: {member.name}")
            if name in payload:
                raise ValueError(f"Duplicate runtime file: {name}")
            if member.size > 256 * 1024 * 1024:
                raise ValueError(f"Oversized runtime file: {name}")
            stream = archive.extractfile(member)
            if stream is None:
                raise ValueError(f"Cannot read runtime file: {name}")
            payload[name] = (member.name, stream.read())
    missing = (spec["required"] | {"LICENSE"}) - payload.keys()
    if missing:
        raise ValueError(f"Missing runtime files: {sorted(missing)}")
    return payload


def verify_payload(payload, variant):
    spec = VARIANTS[variant]
    records = []
    for name in sorted(spec["required"]):
        source_path, data = payload[name]
        metadata = elf_metadata(data)
        dsp = name in DSP_NAMES
        if metadata["machine"] != (164 if dsp else 183):
            raise ValueError(f"{name}: wrong ELF architecture")
        if not dsp and metadata.get("androidApi", spec["minSdk"]) > spec["minSdk"]:
            raise ValueError(f"{name}: requires a newer Android API than the variant")
        if not dsp and any(load["alignment"] < 16384 or
                           (load["address"] - load["offset"]) % 16384
                           for load in metadata["load_segments"]):
            raise ValueError(f"{name}: not 16 KiB aligned")
        allowed = {"libc.so", "libgcc.so"} if dsp else (
            spec["required"] | ANDROID_SYSTEM | spec["external"])
        missing = set(metadata["needed"]) - allowed
        if missing:
            raise ValueError(f"{name}: unpackaged dependencies: {sorted(missing)}")
        records.append({"name": name, "sourcePath": source_path, "bytes": len(data),
                        "sha256": hashlib.sha256(data).hexdigest(), **metadata})
    return records


def prepare(archive_path, variant="cpu", root=ROOT):
    spec = VARIANTS[variant]
    actual = sha256_file(archive_path)
    if actual != spec["sha256"]:
        raise ValueError(f"Archive SHA-256 mismatch: expected {spec['sha256']}, got {actual}")
    payload = read_payload(archive_path, variant)
    records = verify_payload(payload, variant)
    jni = root / "android/app/src/main/jniLibs/arm64-v8a"
    jni.mkdir(parents=True, exist_ok=True)
    # Remove only files owned by this runtime, never speech, MNN or app libraries.
    for path in jni.iterdir():
        if runtime_library(path.name) and path.name not in spec["required"]:
            path.unlink()
    for record in records:
        target = jni / record["name"]
        target.write_bytes(payload[record["name"]][1])
        target.chmod(0o755)
    license_path = root / "assets/licenses/llama-cpp-native.txt"
    license_path.parent.mkdir(parents=True, exist_ok=True)
    license_path.write_bytes(payload["LICENSE"][1])
    manifest = {
        "schemaVersion": 1, "distribution": "official", "version": VERSION, "variant": variant,
        "source": {"repository": "https://github.com/ggml-org/llama.cpp",
                   "tag": VERSION, "buildTag": BUILD, "commit": COMMIT},
        "artifact": {"url": f"{BASE_URL}/{spec['archive']}",
                     "sha256": spec["sha256"], "unmodified": True},
        "abi": "arm64-v8a", "minSdk": spec["minSdk"], "backends": spec["backends"],
        "externalDependencies": sorted(spec["external"]),
        "license": {"asset": "assets/licenses/llama-cpp-native.txt",
                    "sha256": hashlib.sha256(payload["LICENSE"][1]).hexdigest()},
        "libraries": records,
    }
    manifest_path = root / "assets/bin/llama_server_manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--variant", choices=VARIANTS, default="cpu")
    args = parser.parse_args()
    try:
        manifest = prepare(args.archive, args.variant)
    except (OSError, ValueError, KeyError, tarfile.TarError, struct.error) as error:
        parser.exit(1, f"Cannot prepare runtime: {error}\n")
    print(f"Installed {VERSION} official {args.variant}: {len(manifest['libraries'])} files")
    print(f"Archive SHA-256: {manifest['artifact']['sha256']}")
    print("No native code executed. Device/model validation is separate.")


if __name__ == "__main__":
    main()
