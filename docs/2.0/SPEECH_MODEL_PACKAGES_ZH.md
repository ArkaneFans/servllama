# ServLlama 2.0 语音模型包

语音模型在「模型库 → 发现模型」下载，在「模型库 → 语音模型」管理，在「语音」使用。2026-09-28 起隐藏 ZIP 导入页面入口，底层实现与工具保留；以下打包/导入说明用于实现维护，非当前用户操作入口。参见 [模型发现设计](MODEL_DISCOVERY_ZH.md)。ASR/TTS 只在应用内运行，没有对外 HTTP API。模型权重不随源码或 APK 分发。

## 内置目录

元数据、固定 revision、每个文件的大小与 SHA-256 位于 [catalog.json](../../assets/speech/catalog.json)。当前四个包均使用 CPU：

| 配方 ID | 模型 | 必需文件 | 权重及资源总字节 |
|---|---|---|---:|
| `sherpaWhisper` | sherpa-onnx Whisper tiny int8 | encoder、decoder、tokens | 103,609,903 |
| `sherpaVits` | sherpa-onnx AISHELL3 VITS int8 | model、tokens、lexicon、四个 FST | 42,148,978 |
| `crispWhisper` | CrispASR Whisper base | ggml-base.bin | 147,951,465 |
| `crispQwenTts` | CrispASR Qwen3-TTS 0.6B Base Q8 | LLM、音频 codec、默认 voicepack | 1,344,180,928 |

目录只包含已核对的下载元数据；本轮没有下载这些权重或测量真机效果。GGUF/ONNX 的文件大小不等于运行内存需求，Qwen3-TTS 尤其需要在目标手机上核对峰值内存。

选择下载后，文件写入应用自己的包目录。暂停可以继续，重试沿用同一个安装记录；全部文件通过大小、哈希及配方检查后才标为可用。缺失或半安装包不能执行。活动/排队任务引用、正在导入或下载、原生清理未确认时，删除会被阻止。

## 离线打包与导入

ZIP 根目录必须包含 `speech-package.json`，模型文件路径和它的 `files` 一一对应。支持普通 ZIP 和 ZIP64；不接受密码、符号链接、特殊文件、路径穿越、同名或大小写冲突的文件。目录元数据、条目数、实际解压输出分别有上限。

使用 Python 3.10+，从应用仓库执行：

```powershell
python tool/package_speech_model.py --list
python tool/package_speech_model.py --recipe sherpaWhisper --source 'D:/models/sherpa-whisper-tiny' --output 'D:/exports/whisper-tiny-servllama.zip'
```

`--source` 目录里的文件名须与 `--list` 输出一致。打包器不会联网，不会覆盖已有导出，会按实际写入的字节验证内置目录的 SHA-256。路径或哈希不符会失败并清理临时输出。打包时临时 ZIP 和最终 ZIP 会短暂共存，桌面端需预留约两份包的空间。

原页面流程是将生成的 ZIP 复制到手机后选择导入；该入口现已隐藏，代码测试仍可调用 `importArchive`。导入可以取消；失败包显示不可用，可以删除后修复源文件重新导入。手机还需容纳源 ZIP、模型安装目录和文件选择器可能产生的缓存。

四个包的配置角色如下：

```json
{
  "sherpaWhisper": {
    "encoder": "tiny-encoder.int8.onnx",
    "decoder": "tiny-decoder.int8.onnx",
    "tokens": "tiny-tokens.txt"
  },
  "sherpaVits": {
    "model": "vits-aishell3.int8.onnx",
    "tokens": "tokens.txt",
    "lexicon": "lexicon.txt",
    "rules": ["phone.fst", "date.fst", "number.fst", "new_heteronym.fst"]
  },
  "crispWhisper": {"model": "ggml-base.bin"},
  "crispQwenTts": {
    "model": "qwen3-tts-12hz-0.6b-base-q8_0.gguf",
    "codec": "qwen3-tts-tokenizer-12hz.gguf",
    "voice": "qwen3-tts-voice-default.gguf"
  }
}
```

VITS 的发音人 ID 必须小于模型实际报告的发音人数，默认使用 0；合成语速仅对 VITS 开放。Qwen3-TTS Base 支持默认 voicepack 或参考音色，不能用 CustomVoice/Instruct 的权重直接替换 Base 权重。

## 同配方的其他模型

可以给同一受支持架构的本地模型准备自定义定义，例如：

```json
{
  "schemaVersion": 1,
  "recipe": "crispWhisper",
  "name": "My local Whisper model",
  "revision": "local-whisper-2026-09",
  "sourceUrl": "",
  "license": "填写这份模型实际适用的许可",
  "config": {"model": "my-whisper.bin"},
  "files": [{"path": "my-whisper.bin"}]
}
```

```powershell
python tool/package_speech_model.py --manifest 'D:/models/definition.json' --source 'D:/models/custom-whisper' --output 'D:/exports/custom-whisper.zip'
```

工具补齐 `bytes`、`sha256`；定义中已经提供的大小或哈希仍会严格核对。应用侧要求这些字段齐全。包内最多 256 个文件，总资源上限 12 GiB。任意名称相似的模型不一定兼容，实际解析、推理质量、内存与取消行为仍需验收。新增架构需要新增明确配方和适配代码，不通过配置执行脚本。

## 参考音色与结果

- Qwen3-TTS Base：在「语音 → 参考音色」选择模型，导入/录制 3–30 秒音频，填写对应转录并确认有权使用。保存后可以合成试听，也可单独保存资料。
- 参考音频会独立复制并标准化为 24 kHz 单声道 WAV，绑定模型资产 ID 和 revision。排队任务持有自己的参考副本，修改音色不会改写已入队任务。
- 原模型删除或重新安装后，不自动把旧音色迁移到新资产。可以试听、导出旧参考音频，再为新的兼容模型创建音色。
- CrispASR 的默认音频标记及 C2PA 签名保留；没有增加绕过开关。当前 native 构建含 `crispasr_c2pa_sign`，真机签名和音质仍需核对。
- sherpa Whisper 当前以音频块记录近似时间范围，只提供 TXT；Crisp Whisper 的原生分段时间可用于 SRT。编辑转录不会凭空增加词级对齐。

## 来源和许可状态

| 包 | 固定来源 | 本轮核对结果 |
|---|---|---|
| sherpa Whisper | `csukuangfj/sherpa-onnx-whisper-tiny@65176e2deb88badc814a94058666cadccc29b61c` | Whisper 上游为 MIT；转换仓库没有单独声明许可，需要补核转换产物的分发条款 |
| sherpa VITS | `csukuangfj/vits-zh-aishell3@e3e808eaab2385b812286c6707323362251bba65` | 转换仓库未声明许可；需结合原模型 `jackyqs/vits-aishell3-175-chinese`、转换工程与 AISHELL-3 数据条款核对 |
| Crisp Whisper | `ggerganov/whisper.cpp@5359861c739e955e79d9a303bcbc70fb988958b1` | 模型仓库卡片声明 MIT |
| Qwen3-TTS Base | `cstr/qwen3-tts-0.6b-base-GGUF@94072f5c394b4dc4d98e97cc874800dde6ecacda` | 模型仓库卡片声明 Apache-2.0 |
| Qwen codec | `cstr/qwen3-tts-tokenizer-12hz-GGUF@344e279551177654762e5c7d39e217834325f222` | 仓库卡片声明 Apache-2.0 |
| Qwen 默认音色 | `cstr/qwen3-tts-voices-GGUF@6ee1102f782cab1f17842983044ac51cf57884d8` | 仓库卡片声明 Apache-2.0；参考录音的使用权仍由录音来源决定 |

`tool/generate_speech_catalog.py` 只刷新固定来源的元数据和少量辅助文本，不下载模型权重。不要把缺失的模型许可当成已经确认可分发。引擎源码许可和模型/录音的许可是不同的验收事项。
