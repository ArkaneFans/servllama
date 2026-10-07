"""Refresh pinned model metadata only. Does not download model weights."""
import hashlib
import json
import urllib.request
from pathlib import Path

LICENSES = {
    "sherpaWhisper": "Whisper upstream: MIT; the conversion repository does not declare a separate license.",
    "sherpaVits": "Not declared in the converted model card; original model and AISHELL-3 data terms require review.",
    "crispWhisper": "MIT (model repository card).",
    "crispQwenTts": "Apache-2.0 (model, codec and default-voice repository cards).",
}

ENTRIES = [
    ("sherpaWhisper", "Whisper tiny · sherpa-onnx",
     {"encoder": "tiny-encoder.int8.onnx", "decoder": "tiny-decoder.int8.onnx", "tokens": "tiny-tokens.txt"},
     [("csukuangfj/sherpa-onnx-whisper-tiny", "65176e2deb88badc814a94058666cadccc29b61c",
       ["tiny-encoder.int8.onnx", "tiny-decoder.int8.onnx", "tiny-tokens.txt"])]),
    ("sherpaVits", "AISHELL3 · sherpa-onnx",
     {"model": "vits-aishell3.int8.onnx", "tokens": "tokens.txt", "lexicon": "lexicon.txt",
      "rules": ["phone.fst", "date.fst", "number.fst", "new_heteronym.fst"]},
     [("csukuangfj/vits-zh-aishell3", "e3e808eaab2385b812286c6707323362251bba65",
       ["vits-aishell3.int8.onnx", "tokens.txt", "lexicon.txt", "phone.fst", "date.fst", "number.fst", "new_heteronym.fst"])]),
    ("crispWhisper", "Whisper base · CrispASR", {"model": "ggml-base.bin"},
     [("ggerganov/whisper.cpp", "5359861c739e955e79d9a303bcbc70fb988958b1", ["ggml-base.bin"])]),
    ("crispQwenTts", "Qwen3-TTS 0.6B Base · CrispASR",
     {"model": "qwen3-tts-12hz-0.6b-base-q8_0.gguf", "codec": "qwen3-tts-tokenizer-12hz.gguf", "voice": "qwen3-tts-voice-default.gguf"},
     [("cstr/qwen3-tts-0.6b-base-GGUF", "94072f5c394b4dc4d98e97cc874800dde6ecacda", ["qwen3-tts-12hz-0.6b-base-q8_0.gguf"]),
      ("cstr/qwen3-tts-tokenizer-12hz-GGUF", "344e279551177654762e5c7d39e217834325f222", ["qwen3-tts-tokenizer-12hz.gguf"]),
      ("cstr/qwen3-tts-voices-GGUF", "6ee1102f782cab1f17842983044ac51cf57884d8", ["qwen3-tts-voice-default.gguf"])])
]
def main():
    output = []
    for recipe, label, config, repos in ENTRIES:
        files = []
        for repo, revision, names in repos:
            with urllib.request.urlopen("https://huggingface.co/api/models/" + repo + "/revision/" + revision + "?blobs=true", timeout=30) as r:
                metadata = json.load(r)
            for name in names:
                entry = next(x for x in metadata["siblings"] if x["rfilename"] == name)
                url = "https://huggingface.co/" + repo + "/resolve/" + revision + "/" + name
                digest = entry.get("lfs", {}).get("sha256")
                size = entry.get("size")
                if not digest:
                    if size > 32 * 1024 * 1024:
                        raise ValueError("Missing weight hash: " + name)
                    with urllib.request.urlopen(url, timeout=30) as r:
                        data = r.read()
                    digest = hashlib.sha256(data).hexdigest()
                    size = len(data)
                files.append({"path": name, "bytes": size, "sha256": digest, "url": url})
        output.append({"schemaVersion": 1, "recipe": recipe, "name": label, "revision": repos[0][1],
                       "sourceUrl": "https://huggingface.co/" + repos[0][0],
                       "license": LICENSES[recipe],
                       "config": config, "files": files})
        print(recipe, sum(f["bytes"] for f in files))
    path = Path(__file__).resolve().parents[1] / "assets/speech/catalog.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

if __name__ == "__main__":
    main()
