import 'package:mnn_engine/mnn_engine.dart'
    show MnnBackend, MnnLoadOptions, MnnPrecision;
import 'package:servllama/core/models/llama_cpp_backend.dart';

enum ServerListenMode { localhost, allInterfaces }

enum FlashAttentionMode { auto, enabled, disabled }

enum ServerLogLevel { error, warning, info, debug }

class ServerLaunchSettings {
  const ServerLaunchSettings({
    this.listenMode = ServerListenMode.localhost,
    this.port = defaultPort,
    this.apiKey = '',
    this.contextSize = defaultContextSize,
    this.cpuThreads = defaultCpuThreads,
    this.batchSize = defaultBatchSize,
    this.parallelSlots = defaultParallelSlots,
    this.imageMaxTokens = defaultImageMaxTokens,
    this.flashAttentionMode = defaultFlashAttentionMode,
    this.useMmap = true,
    this.logEnabled = true,
    this.logLevel = defaultLogLevel,
    this.llamaCppBackend = defaultLlamaCppBackend,
    this.llamaCppGpuLayers = defaultLlamaCppGpuLayers,
    this.mnnBackend = MnnBackend.cpu,
    this.mnnUseMmap = defaultMnnUseMmap,
    this.mnnPrecision = defaultMnnPrecision,
    this.mnnThreadNum = defaultMnnThreadNum,
  });

  static const int defaultPort = 8080;
  static const int minPort = 1;
  static const int maxPort = 65535;

  static const int defaultContextSize = 4096;
  static const int minContextSize = 512;
  static const int maxContextSize = 65536;

  static const int defaultCpuThreads = 4;
  static const int minCpuThreads = 1;
  static const int maxCpuThreads = 8;

  static const int defaultBatchSize = 2048;
  static const int minBatchSize = 32;
  static const int maxBatchSize = 4096;

  static const int defaultParallelSlots = 1;
  static const int minParallelSlots = 1;
  static const int maxParallelSlots = 8;

  static const int defaultImageMaxTokens = 256;
  static const int minImageMaxTokens = 128;
  static const int maxImageMaxTokens = 4096;

  static const FlashAttentionMode defaultFlashAttentionMode =
      FlashAttentionMode.disabled;
  static const ServerLogLevel defaultLogLevel = ServerLogLevel.info;
  static const LlamaCppBackend defaultLlamaCppBackend = LlamaCppBackend.cpu;
  static const int defaultLlamaCppGpuLayers = 99;
  static const int minLlamaCppGpuLayers = 1;
  static const int maxLlamaCppGpuLayers = 128;
  static const bool defaultMnnUseMmap = MnnLoadOptions.defaultUseMmap;
  static const MnnPrecision defaultMnnPrecision =
      MnnLoadOptions.defaultPrecision;
  static const int defaultMnnThreadNum = MnnLoadOptions.defaultThreadNum;
  static const int minMnnThreadNum = MnnLoadOptions.minThreadNum;
  static const int maxMnnThreadNum = MnnLoadOptions.maxThreadNum;

  // Hexagon remains in the plugin for development, but is not offered by
  // ServLlama until its model compatibility and device support are ready.
  static const supportedMnnBackends = [
    MnnBackend.cpu,
    MnnBackend.opencl,
    MnnBackend.vulkan,
  ];

  // Shown and launched backends. A compiled backend can stay in
  // [LlamaCppBackend] and still be reported by the device probe; remove it
  // from this list to hide it. CPU stays first and is the fallback.
  // OpenCL is compiled, but Adreno results are not reliable enough to offer.
  static const List<LlamaCppBackend> supportedLlamaCppBackends = [
    LlamaCppBackend.cpu,
    LlamaCppBackend.hexagon,
  ];

  final ServerListenMode listenMode;
  final int port;
  final String apiKey;
  final int contextSize;
  final int cpuThreads;
  final int batchSize;
  final int parallelSlots;
  final int imageMaxTokens;
  final FlashAttentionMode flashAttentionMode;
  final bool useMmap;
  final bool logEnabled;
  final ServerLogLevel logLevel;
  final LlamaCppBackend llamaCppBackend;
  final int llamaCppGpuLayers;
  final MnnBackend mnnBackend;
  final bool mnnUseMmap;
  final MnnPrecision mnnPrecision;
  final int mnnThreadNum;

  String get host =>
      listenMode == ServerListenMode.localhost ? '127.0.0.1' : '0.0.0.0';

  ServerLaunchSettings copyWith({
    ServerListenMode? listenMode,
    int? port,
    String? apiKey,
    int? contextSize,
    int? cpuThreads,
    int? batchSize,
    int? parallelSlots,
    int? imageMaxTokens,
    FlashAttentionMode? flashAttentionMode,
    bool? useMmap,
    bool? logEnabled,
    ServerLogLevel? logLevel,
    LlamaCppBackend? llamaCppBackend,
    int? llamaCppGpuLayers,
    MnnBackend? mnnBackend,
    bool? mnnUseMmap,
    MnnPrecision? mnnPrecision,
    int? mnnThreadNum,
  }) {
    return ServerLaunchSettings(
      listenMode: listenMode ?? this.listenMode,
      port: port ?? this.port,
      apiKey: apiKey ?? this.apiKey,
      contextSize: contextSize ?? this.contextSize,
      cpuThreads: cpuThreads ?? this.cpuThreads,
      batchSize: batchSize ?? this.batchSize,
      parallelSlots: parallelSlots ?? this.parallelSlots,
      imageMaxTokens: imageMaxTokens ?? this.imageMaxTokens,
      flashAttentionMode: flashAttentionMode ?? this.flashAttentionMode,
      useMmap: useMmap ?? this.useMmap,
      logEnabled: logEnabled ?? this.logEnabled,
      logLevel: logLevel ?? this.logLevel,
      llamaCppBackend: llamaCppBackend ?? this.llamaCppBackend,
      llamaCppGpuLayers: llamaCppGpuLayers ?? this.llamaCppGpuLayers,
      mnnBackend: mnnBackend ?? this.mnnBackend,
      mnnUseMmap: mnnUseMmap ?? this.mnnUseMmap,
      mnnPrecision: mnnPrecision ?? this.mnnPrecision,
      mnnThreadNum: mnnThreadNum ?? this.mnnThreadNum,
    );
  }

  /// Maps a stored name onto [offered]. Legacy auto and unknown names
  /// become [defaultLlamaCppBackend].
  static LlamaCppBackend llamaCppBackendFromStorage(
    String? value, {
    List<LlamaCppBackend> offered = supportedLlamaCppBackends,
  }) {
    if (value == null || value == 'auto') return defaultLlamaCppBackend;
    for (final backend in offered) {
      if (backend.name == value) return backend;
    }
    return defaultLlamaCppBackend;
  }
}

extension ServerLogLevelX on ServerLogLevel {
  int get cliValue {
    switch (this) {
      case ServerLogLevel.error:
        return 1;
      case ServerLogLevel.warning:
        return 2;
      case ServerLogLevel.info:
        return 3;
      case ServerLogLevel.debug:
        return 4;
    }
  }
}

extension FlashAttentionModeX on FlashAttentionMode {
  String get cliValue {
    switch (this) {
      case FlashAttentionMode.auto:
        return 'auto';
      case FlashAttentionMode.enabled:
        return 'on';
      case FlashAttentionMode.disabled:
        return 'off';
    }
  }
}
