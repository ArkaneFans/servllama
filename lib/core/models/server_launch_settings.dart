enum ServerListenMode { localhost, allInterfaces }

enum FlashAttentionMode { auto, enabled, disabled }

enum ServerLogLevel { error, warning, info, debug }

class ServerLaunchSettings {
  const ServerLaunchSettings({
    this.listenMode = ServerListenMode.localhost,
    this.port = defaultPort,
    this.apiKey = '',
    this.device = defaultDevice,
    this.gpuLayers = defaultGpuLayers,
    this.contextSize = defaultContextSize,
    this.cpuThreads = defaultCpuThreads,
    this.batchSize = defaultBatchSize,
    this.parallelSlots = defaultParallelSlots,
    this.imageMaxTokens = defaultImageMaxTokens,
    this.flashAttentionMode = defaultFlashAttentionMode,
    this.useMmap = true,
    this.logEnabled = true,
    this.logLevel = defaultLogLevel,
  });

  static const int defaultPort = 8080;
  static const int minPort = 1;
  static const int maxPort = 65535;

  /// Empty string means CPU-only inference (`--device none`).
  static const String defaultDevice = '';

  /// -1 lets llama-server decide how many layers to offload.
  static const int autoGpuLayers = -1;
  static const int defaultGpuLayers = autoGpuLayers;
  static const int minGpuLayers = 0;
  static const int maxGpuLayers = 99;

  static const int defaultContextSize = 4096;
  static const int minContextSize = 512;
  static const int maxContextSize = 65536;

  static const int defaultCpuThreads = 2;
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

  final ServerListenMode listenMode;
  final int port;
  final String apiKey;
  final String device;
  final int gpuLayers;
  final int contextSize;
  final int cpuThreads;
  final int batchSize;
  final int parallelSlots;
  final int imageMaxTokens;
  final FlashAttentionMode flashAttentionMode;
  final bool useMmap;
  final bool logEnabled;
  final ServerLogLevel logLevel;

  bool get isCpuDevice => device.isEmpty;

  String get host =>
      listenMode == ServerListenMode.localhost ? '127.0.0.1' : '0.0.0.0';

  ServerLaunchSettings copyWith({
    ServerListenMode? listenMode,
    int? port,
    String? apiKey,
    String? device,
    int? gpuLayers,
    int? contextSize,
    int? cpuThreads,
    int? batchSize,
    int? parallelSlots,
    int? imageMaxTokens,
    FlashAttentionMode? flashAttentionMode,
    bool? useMmap,
    bool? logEnabled,
    ServerLogLevel? logLevel,
  }) {
    return ServerLaunchSettings(
      listenMode: listenMode ?? this.listenMode,
      port: port ?? this.port,
      apiKey: apiKey ?? this.apiKey,
      device: device ?? this.device,
      gpuLayers: gpuLayers ?? this.gpuLayers,
      contextSize: contextSize ?? this.contextSize,
      cpuThreads: cpuThreads ?? this.cpuThreads,
      batchSize: batchSize ?? this.batchSize,
      parallelSlots: parallelSlots ?? this.parallelSlots,
      imageMaxTokens: imageMaxTokens ?? this.imageMaxTokens,
      flashAttentionMode: flashAttentionMode ?? this.flashAttentionMode,
      useMmap: useMmap ?? this.useMmap,
      logEnabled: logEnabled ?? this.logEnabled,
      logLevel: logLevel ?? this.logLevel,
    );
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
