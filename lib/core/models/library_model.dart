import 'package:servllama/core/models/inference_engine.dart';

/// One entry of the unified model library. GGUF models (llama.cpp) and MNN
/// model directories are listed side by side and told apart by [engine]
/// (design decision D2).
class LibraryModel {
  const LibraryModel({
    required this.id,
    required this.runtimeId,
    required this.engine,
    required this.name,
    required this.sizeBytes,
    required this.importedAt,
    required this.storagePath,
    this.supportsVision = false,
    this.supportsToolCalling = false,
    this.hasMmproj = false,
    this.warnings = const <String>[],
  });

  /// Stable key for library operations (rename, delete). Namespaced by engine
  /// because the two stores generate ids independently.
  final String id;

  /// Identifier the engine itself uses when asked to load this model:
  /// `llama-server`'s `--models-dir` entry name, or MNN's model id.
  final String runtimeId;

  final InferenceEngine engine;
  final String name;
  final int sizeBytes;
  final DateTime importedAt;

  /// GGUF file path, or MNN model directory path.
  final String storagePath;

  final bool supportsVision;
  final bool supportsToolCalling;

  /// llama.cpp only: a sibling `mmproj-*.gguf` enabling image input.
  final bool hasMmproj;

  final List<String> warnings;
}
