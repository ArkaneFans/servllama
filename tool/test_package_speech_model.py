import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

from package_speech_model import package_model


class SpeechPackagingTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="servllama-package-")
        self.root = Path(self.temp.name)
        self.source = self.root / "source"
        self.source.mkdir()
        (self.source / "model.bin").write_bytes(b"ggml fixture")
        self.definition = {"schemaVersion": 1, "name": "Fixture", "revision": "test",
                           "recipe": "crispWhisper", "config": {"model": "model.bin"},
                           "files": [{"path": "model.bin"}]}
        self.output = self.root / "model.zip"

    def tearDown(self):
        self.temp.cleanup()

    def test_archive_bytes_match_self_contained_manifest(self):
        package_model(self.definition, self.source, self.output)
        with zipfile.ZipFile(self.output) as archive:
            manifest = json.loads(archive.read("speech-package.json"))
            data = archive.read("model.bin")
            self.assertEqual(archive.testzip(), None)
            self.assertEqual(manifest["files"][0]["sha256"], hashlib.sha256(data).hexdigest())
            self.assertEqual(manifest["files"][0]["bytes"], len(data))
        self.assertNotIn("sha256", self.definition["files"][0])

    def test_incorrect_pinned_hash_leaves_no_deliverable(self):
        self.definition["files"][0]["sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            package_model(self.definition, self.source, self.output)
        self.assertFalse(self.output.exists())
        self.assertEqual(list(self.root.glob("*.part-*")), [])

    def test_rejects_traversal_and_never_overwrites_an_existing_export(self):
        self.definition["files"][0]["path"] = "../model.bin"
        with self.assertRaises(ValueError):
            package_model(self.definition, self.source, self.output)
        self.definition["files"][0]["path"] = "model.bin"
        self.output.write_bytes(b"existing export")
        with self.assertRaises(FileExistsError):
            package_model(self.definition, self.source, self.output)
        self.assertEqual(self.output.read_bytes(), b"existing export")


if __name__ == "__main__":
    unittest.main()
