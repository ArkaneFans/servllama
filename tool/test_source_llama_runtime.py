"""Source-route contract fixtures, not a Hexagon compiler/device test.

Exercise the unchanged source packager and its legacy workflow manifest using
synthetic ELF bytes. No native code is executed.
"""

import json
from pathlib import Path
import subprocess
import struct
import sys
import unittest
from unittest.mock import patch
import zipfile

import prepare_llama_runtime as runtime
import verify_android_bundle as bundle
import test_prepare_llama_runtime as fixtures


class SourceRuntimeTest(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.RuntimeTest()
        self.fixture.setUp()
        self.addCleanup(self.fixture.tearDown)
        self.addCleanup(self.fixture.doCleanups)
        self.root = self.fixture.root
        self.fixture.make_apk()
        self.jni = self.root / "source-jni"
        self.prefix = self.root / "source-prefix"
        (self.prefix / "bin").mkdir(parents=True)
        (self.prefix / "lib").mkdir()
        self.names = bundle.SOURCE_CORE | bundle.SOURCE_DSP | {
            "libggml-cpu-armv8.so", "libggml-htp-v85.so",
        }
        for name in self.names:
            dsp = name.startswith("libggml-htp-")
            data = fixtures.elf(164 if dsp else 183, 4096 if dsp else 16384) + b"source-fixture"
            relative = "bin/llama-server" if name == "libllama-server.so" else "lib/" + name
            (self.prefix / relative).write_bytes(data)
        self.packager = Path(__file__).resolve().parents[1] / "patches/llama.cpp/package_jni_libs.py"
        self.package()
        # Exact shape emitted by the unchanged source GitHub Actions workflow.
        self.manifest = {"version": "v0.8.0"}

    def package(self):
        result = subprocess.run([sys.executable, str(self.packager), str(self.prefix),
                                 str(self.jni)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def make_source_apk(self, missing=(), mutate=None, extra=None):
        original = self.root / "test.apk"
        target = self.root / "source.apk"
        asset = "assets/flutter_assets/assets/bin/llama_server_manifest.json"
        with zipfile.ZipFile(original) as source, zipfile.ZipFile(target, "w") as dest:
            for name in source.namelist():
                if name == asset or (name.startswith("lib/") and runtime.runtime_library(name.rsplit("/", 1)[-1])):
                    continue
                dest.writestr(name, source.read(name))
            for name in sorted(self.names - set(missing)):
                data = (self.jni / name).read_bytes()
                if name == mutate:
                    data += b"modified"
                dest.writestr("lib/arm64-v8a/" + name, data)
            if extra:
                dest.writestr("lib/arm64-v8a/" + extra, fixtures.elf())
            dest.writestr(asset, json.dumps(self.manifest))
        manifest_path = self.root / "source-manifest.json"
        manifest_path.write_text(json.dumps(self.manifest))
        with patch.object(bundle, "ROOT", self.root):
            return bundle.audit(target, self.root / "speech.json", self.jni,
                                manifest_path)

    def test_original_source_packager_and_manifest_are_accepted(self):
        report = self.make_source_apk()
        self.assertTrue(report["passed"], report["errors"])
        self.assertEqual(report["llama_distribution"], "source")
        self.assertEqual(report["runtime_min_sdk"], 28)
        self.assertEqual(sum(item.get("source_build_matches", False)
                             for item in report["libraries"]), len(self.names))
        self.assertFalse(any("official_source_matches" in item for item in report["libraries"]))

    def test_source_audit_rejects_missing_opencl(self):
        report = self.make_source_apk(missing={"libggml-opencl.so"})
        self.assertFalse(report["passed"])
        self.assertTrue(any("Missing libraries" in error for error in report["errors"]))

    def test_source_audit_rejects_missing_dsp(self):
        report = self.make_source_apk(missing={"libggml-htp-v73.so"})
        self.assertFalse(report["passed"])

    def test_source_audit_rejects_missing_cpu_variants(self):
        self.names.remove("libggml-cpu-armv8.so")
        (self.jni / "libggml-cpu-armv8.so").unlink()
        report = self.make_source_apk()
        self.assertFalse(report["passed"])
        self.assertIn("Source runtime is missing CPU variants", report["errors"])

    def test_source_audit_rejects_modified_native_bytes(self):
        report = self.make_source_apk(mutate="libllama.so")
        self.assertFalse(report["passed"])
        self.assertTrue(any("supplied source-build JNI original" in error for error in report["errors"]))

    def test_source_audit_rejects_mixed_official_runtime(self):
        report = self.make_source_apk(extra="libggml-rpc.so")
        self.assertFalse(report["passed"])
        self.assertTrue(any("mixed llama.cpp" in error for error in report["errors"]))

    def test_source_jni_rejects_mixed_official_runtime(self):
        (self.jni / "libggml-cpu.so").write_bytes(fixtures.elf())
        report = self.make_source_apk()
        self.assertFalse(report["passed"])
        self.assertTrue(any("mixed source runtime" in error for error in report["errors"]))

    def test_source_packager_rejects_missing_opencl(self):
        (self.prefix / "lib/libggml-opencl.so").unlink()
        result = subprocess.run([sys.executable, str(self.packager), str(self.prefix),
                                 str(self.root / "incomplete-jni")], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("libggml-opencl.so", result.stdout)

    def test_source_audit_rejects_unresolved_dependency(self):
        (self.jni / "libllama.so").write_bytes(fixtures.elf(dependency="libmissing.so"))
        report = self.make_source_apk()
        self.assertFalse(report["passed"])
        self.assertTrue(any("unresolved source dependencies" in error for error in report["errors"]))

    def test_source_audit_rejects_android_api_above_28(self):
        data = bytearray(fixtures.elf())
        struct.pack_into("<H", data, 56, 2)
        struct.pack_into("<IIQQQQQQ", data, 120, 4, 4, 200, 200, 200, 24, 24, 4)
        struct.pack_into("<III", data, 200, 8, 4, 1)
        data[212:220] = b"Android\0"
        struct.pack_into("<I", data, 220, 34)
        (self.jni / "libllama.so").write_bytes(data)
        report = self.make_source_apk()
        self.assertFalse(report["passed"])
        self.assertTrue(any("Android API above 28" in error for error in report["errors"]))

    def test_source_audit_rejects_bad_alignment(self):
        (self.jni / "libllama.so").write_bytes(fixtures.elf(alignment=4096))
        report = self.make_source_apk()
        self.assertFalse(report["passed"])
        self.assertTrue(any("not 16 KiB aligned" in error for error in report["errors"]))

    def test_incomplete_official_manifest_does_not_fall_back(self):
        for marker, value in {"distribution": "official", "schemaVersion": 1,
                              "variant": "cpu", "source": {}, "artifact": {},
                              "libraries": [], "minSdk": 28, "license": {}}.items():
            with self.subTest(marker=marker), self.assertRaises(ValueError):
                bundle.runtime_distribution({"version": "v0.8.0", marker: value})

    def test_explicit_source_cannot_hide_official_markers(self):
        with self.assertRaises(ValueError):
            bundle.runtime_distribution({"version": "v0.8.0", "distribution": "source",
                                         "artifact": {"unmodified": True}})

    def test_empty_source_version_is_rejected(self):
        for value in ("", " ", None, 8):
            with self.subTest(value=value), self.assertRaises(ValueError):
                bundle.runtime_distribution({"version": value})

    def test_legacy_official_manifest_stays_official(self):
        manifest = json.loads((self.root / "assets/bin/llama_server_manifest.json").read_text())
        self.assertEqual(manifest.pop("distribution"), "official")
        self.assertEqual(bundle.runtime_distribution(manifest), "official")


if __name__ == "__main__":
    unittest.main()
