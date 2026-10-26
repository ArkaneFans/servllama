# Offline Speech Models

The preset catalog is `assets/speech/catalog.json`. Packages pin each download
to a repository revision, exact byte length and SHA-256. Installation and ZIP
import share `SpeechModelService` validation and the unified model index.

## CrispASR TTS Preset

The catalog uses **CosyVoice3 0.5B Q4_K** from
[cstr/cosyvoice3-0.5b-2512-GGUF](https://huggingface.co/cstr/cosyvoice3-0.5b-2512-GGUF),
revision `aa0ea5eb7279bcf54668bcbaa7348019de7d7178`.

- The 786,910,496-byte package includes the Q4_K LLM, Q8_0 flow model, F16
  HiFT vocoder and baked voice bank. This is approximately 750.5 MiB, or 41%
  smaller than the previous 1,344,180,928-byte Qwen3-TTS Base package.
- The upstream model supports Chinese and other languages including English,
  Japanese, Korean, German, French and Spanish. Language tags in the package
  mirror the conversion repository's model card; they are not device QA results.
- The backend uses its default baked voice. No reference recording, cloning
  encoder or speech-tokenizer download is needed for this synthesis path.
- Models use Apache-2.0 licensing; the bank also includes FLEURS prompt samples
  with CC-BY-4.0 terms. Download size does not measure runtime memory or latency.

`SpeechRecipe.crispCosyVoiceTts` dispatches to the existing native
`cosyvoice3-tts` backend in the pinned CrispASR 0.8.37 bundle. See
`native/speech/android-arm64-v8a.json` for native provenance. No native rebuild
or dependency upgrade accompanies this catalog change.

CrispASR discovers the flow, HiFT and voice bank by fixed filenames next to the
LLM. Package validation enforces those names and their placement, as well as
the usual file sizes, GGUF magic and checksums. The worker does not invoke
`setCodecPath()` or `setVoice()` for this recipe; native opening loads the
companions and ordinary synthesis uses the backend's default voice.

The preset exposes neither voice cloning nor synthesis-speed controls. Ordinary
`synthesize()` watermarking and final WAV C2PA signing remain enabled. The UI
continues to disclose CrispASR marking even though this recipe cannot clone.

## Existing Installations

The old `crispQwenTts` recipe remains supported for installed/imported packages
and saved job snapshots. Replacing the catalog entry does not delete existing
weights, change the user's selected TTS model, or rewrite previous jobs. Users
can download CosyVoice3 and explicitly select it; no silent model fallback occurs.

## Verification

Host coverage checks catalog metadata, recipe dispatch, GGUF validation,
companion download/import and model-discovery filtering.
Run `flutter analyze` and the speech/download discovery tests after changes.

On Android arm64, download the pinned package and synthesize short and multi-
sentence Chinese and English inputs. Verify playback, export, cancellation,
FIFO cleanup and long-input completeness. Host tests and model-card language
claims do not establish device synthesis quality or performance.
