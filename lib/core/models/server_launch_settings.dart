enum ServerListenMode { localhost, allInterfaces }

enum FlashAttentionMode { auto, enabled, disabled }

class ServerLaunchSettings {
  const ServerLaunchSettings({
    this.listenMode = ServerListenMode.localhost,
    this.port = defaultPort,
    this.apiKey = '',
    this.contextSize = defaultContextSize,
    this.cpuThreads = defaultCpuThreads,
    this.batchSize = defaultBatchSize,
    this.parallelSlots = defaultParallelSlots,
    this.flashAttentionMode = defaultFlashAttentionMode,
    this.useMmap = true,
  });

  static const int defaultPort = 8080;
  static const int minPort = 1;
  static const int maxPort = 65535;

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

  static const FlashAttentionMode defaultFlashAttentionMode =
      FlashAttentionMode.disabled;

  final ServerListenMode listenMode;
  final int port;
  final String apiKey;
  final int contextSize;
  final int cpuThreads;
  final int batchSize;
  final int parallelSlots;
  final FlashAttentionMode flashAttentionMode;
  final bool useMmap;

  String get host =>
      listenMode == ServerListenMode.localhost ? '127.0.0.1' : '0.0.0.0';
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
