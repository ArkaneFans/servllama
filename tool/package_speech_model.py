"""Build an offline ServLlama speech ZIP, without downloading model weights.

Use --recipe for the pinned catalogue, or --manifest for another model using
one of the four supported recipes. A custom manifest may omit file hashes and
sizes; the packager fills them from the bytes it actually writes.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import uuid
import zipfile


CATALOG = Path(__file__).resolve().parents[1] / "assets/speech/catalog.json"
ROLES = {
    "sherpaWhisper": ("encoder", "decoder", "tokens"),
    "sherpaVits": ("model", "tokens", "lexicon"),
    "crispWhisper": ("model",),
    "crispQwenTts": ("model", "codec", "voice"),
}
MAX_BYTES = 12 * 1024**3


def validate_definition(definition):
    if definition.get("schemaVersion") != 1 or definition.get("recipe") not in ROLES:
        raise ValueError("Use schemaVersion 1 and a supported recipe")
    for key, limit in (("name", 120), ("revision", 256)):
        value = definition.get(key)
        if not isinstance(value, str) or not value.strip() or len(value) > limit:
            raise ValueError("Invalid " + key)
    files = definition.get("files", [])
    if not 1 <= len(files) <= 256:
        raise ValueError("A package needs 1-256 files")
    names = set()
    for spec in files:
        name = spec["path"]
        if (not isinstance(name, str) or not name or len(name) > 200
                or "\\" in name or ":" in name or any(ord(c) < 32 for c in name)
                or name.startswith("/") or any(p in ("", ".", "..") for p in name.split("/"))
                or name.lower() == "speech-package.json" or name.endswith(".part")
                or PurePosixPath(name).as_posix() != name or name.lower() in names):
            raise ValueError("Unsafe or duplicate file path: " + str(name))
        names.add(name.lower())
    exact_names = {s["path"] for s in files}
    config = definition.get("config", {})
    for role in ROLES[definition["recipe"]]:
        if config.get(role) not in exact_names:
            raise ValueError("Missing dependency for role: " + role)
    for name in config.get("rules", []):
        if name not in exact_names:
            raise ValueError("Missing text normalization rule: " + name)


def package_model(definition, source, output):
    validate_definition(definition)
    source = Path(source).resolve(strict=True)
    output = Path(output).absolute()
    if not source.is_dir() or output.suffix.lower() != ".zip":
        raise ValueError("Use a source directory and a .zip output")
    if output.exists():
        raise FileExistsError("Output already exists: " + str(output))
    # Resolve every input before creating any output. Never traverse links or
    # accidentally include an earlier archive from the input directory.
    inputs = []
    for spec in definition["files"]:
        candidate = source / spec["path"]
        relative = PurePosixPath(spec["path"])
        parents = [source.joinpath(*relative.parts[:i]) for i in range(1, len(relative.parts) + 1)]
        resolved = candidate.resolve(strict=True)
        if any(p.is_symlink() for p in parents) or not resolved.is_relative_to(source) or not resolved.is_file():
            raise ValueError("Model files must be regular files inside the source: " + spec["path"])
        if not 0 < resolved.stat().st_size <= MAX_BYTES:
            raise ValueError("Invalid model file size: " + spec["path"])
        inputs.append((spec, resolved))
    output.parent.mkdir(parents=True, exist_ok=True)
    staging = output.with_name(output.name + ".part-" + uuid.uuid4().hex)
    total = 0
    manifest = dict(definition, files=[])
    try:
        with zipfile.ZipFile(staging, "x", compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
            for spec, path in inputs:
                digest = hashlib.sha256()
                size = 0
                info = zipfile.ZipInfo(spec["path"])
                info.external_attr = 0o100644 << 16
                with path.open("rb") as stream, archive.open(info, "w", force_zip64=True) as target:
                    while chunk := stream.read(1024 * 1024):
                        size += len(chunk)
                        total += len(chunk)
                        if total > MAX_BYTES:
                            raise ValueError("Expanded model exceeds 12 GiB")
                        digest.update(chunk)
                        target.write(chunk)
                actual = digest.hexdigest()
                if spec.get("bytes") is not None and spec["bytes"] != size:
                    raise ValueError("Size differs from manifest: " + spec["path"])
                if spec.get("sha256") is not None and spec["sha256"].lower() != actual:
                    raise ValueError("SHA-256 differs from manifest: " + spec["path"])
                if size == 0:
                    raise ValueError("Empty model file: " + spec["path"])
                manifest["files"].append(dict(spec, bytes=size, sha256=actual))
            archive.writestr("speech-package.json", json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        # Exclusive final creation also protects a file created by another
        # process during packaging. Copy in bounded chunks on all platforms.
        with output.open("xb") as target, staging.open("rb") as stream:
            try:
                while chunk := stream.read(1024 * 1024):
                    target.write(chunk)
                target.flush()
                os.fsync(target.fileno())
            except BaseException:
                target.close()
                output.unlink(missing_ok=True)
                raise
        return manifest
    finally:
        staging.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--recipe", choices=ROLES)
    group.add_argument("--manifest", type=Path, help="Custom JSON definition; files may omit bytes/sha256")
    group.add_argument("--list", action="store_true", help="List pinned packages and required filenames")
    parser.add_argument("--source", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    if args.list:
        for entry in catalog:
            print(entry["recipe"], entry["revision"], sum(f["bytes"] for f in entry["files"]))
            for spec in entry["files"]:
                print("  " + spec["path"])
        return
    if not args.source or not args.output:
        parser.error("--source and --output are required for packaging")
    definition = (json.loads(args.manifest.read_text(encoding="utf-8")) if args.manifest
                  else next(e for e in catalog if e["recipe"] == args.recipe))
    try:
        result = package_model(definition, args.source, args.output)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, "Cannot package model: " + str(error) + "\n")
    print(str(args.output) + ": " + str(sum(f["bytes"] for f in result["files"])) + " model bytes verified")


if __name__ == "__main__":
    main()
