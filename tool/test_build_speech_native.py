import unittest

from build_speech_native import REQUIRED_SYMBOLS, validate_native


class NativeBundleValidationTest(unittest.TestCase):
    def setUp(self):
        self.dynamic = "0x01 (NEEDED) Shared library: [libc.so]\n"
        self.segments = "  LOAD 0x000000 0x000000 0x000000 0x1000 0x1000 R E 0x4000\n"
        self.symbols = "\n".join(f"00010000 T {name}" for name in REQUIRED_SYMBOLS)

    def test_valid_bundle(self):
        self.assertEqual(validate_native(self.dynamic, self.segments, self.symbols), ["libc.so"])

    def test_unbundled_dependency_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "conflicting dependencies"):
            validate_native(self.dynamic + "Shared library: [libggml.so]", self.segments, self.symbols)

    def test_missing_load_segments_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "16 KiB"):
            validate_native(self.dynamic, "", self.symbols)

    def test_unaligned_library_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "16 KiB"):
            validate_native(self.dynamic, self.segments.replace("0x4000", "0x1000"), self.symbols)

    def test_missing_abi_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "Missing speech ABI"):
            validate_native(self.dynamic, self.segments, "")

    def test_ggml_symbol_leak_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "Unisolated native symbols"):
            validate_native(self.dynamic, self.segments, self.symbols + "\n00010000 T ggml_init")

    def test_versioned_abi_symbols_accepted(self):
        symbols = self.symbols.replace("\n", "@@SERVLLAMA_CRISPASR_1\n")
        symbols += "@@SERVLLAMA_CRISPASR_1\n00000000 A SERVLLAMA_CRISPASR_1"
        self.assertEqual(validate_native(self.dynamic, self.segments, symbols), ["libc.so"])


if __name__ == "__main__":
    unittest.main()
