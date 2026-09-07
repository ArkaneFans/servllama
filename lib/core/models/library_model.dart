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
    this.sourceValue,
    this.repoId,
    this.revision,
    this.warnings = const <String>[],
  });

  /// Key for library operations (rename, delete). Namespaced by engine because
  /// the two stores generate ids independently. MNN renames change this key
  /// because its directory name is also its native model id.
  final String id;

  /// Identifier the engine itself uses when asked to load this model. For both
  /// engines this is the model directory name.
  final String runtimeId;

  final InferenceEngine engine;
  final String name;
  final int sizeBytes;
  final DateTime importedAt;

  /// GGUF file path, or MNN model directory path.
  final String storagePath;

  final bool supportsVision;
  final bool supportsToolCalling;

  /// llama.cpp only: a sibling GGUF whose name contains `mmproj`, enabling image input.
  final bool hasMmproj;

  /// Hub source of a downloaded GGUF. Null for local imports and MNN models.
  final String? sourceValue;
  final String? repoId;
  final String? revision;

  final List<String> warnings;

  bool get canDownloadMmproj {
    if (engine != InferenceEngine.llamaCpp) {
      return false;
    }
    final source = sourceValue?.trim();
    final repo = repoId?.trim();
    return source != null &&
        source.isNotEmpty &&
        repo != null &&
        repo.isNotEmpty;
  }
}
