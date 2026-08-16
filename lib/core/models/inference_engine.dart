/// The inference backends the app can run. Exactly one is active at a time
/// (design decision D1) and the active one owns the configured port.
enum InferenceEngine {
  llamaCpp,
  mnn;

  static InferenceEngine fromStorageValue(String? value) {
    for (final engine in InferenceEngine.values) {
      if (engine.storageValue == value) {
        return engine;
      }
    }
    return InferenceEngine.llamaCpp;
  }

  String get storageValue {
    switch (this) {
      case InferenceEngine.llamaCpp:
        return 'llama_cpp';
      case InferenceEngine.mnn:
        return 'mnn';
    }
  }

  /// Engine name as shown to users. Both are product names, so they are the
  /// same in every locale and intentionally live outside the ARB files.
  String get displayName {
    switch (this) {
      case InferenceEngine.llamaCpp:
        return 'llama.cpp';
      case InferenceEngine.mnn:
        return 'MNN';
    }
  }

  /// Model container shape: GGUF ships as a single file, MNN as a directory.
  bool get usesDirectoryModels => this == InferenceEngine.mnn;
}
