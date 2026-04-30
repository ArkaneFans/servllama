class ServerPrefsKeys {
  const ServerPrefsKeys._();

  static const String listenMode = 'server.listen_mode';
  static const String port = 'server.port';
  static const String apiKey = 'server.api_key';
  static const String contextSize = 'server.context_size';
  static const String cpuThreads = 'server.cpu_threads';
  static const String batchSize = 'server.batch_size';
  static const String parallelSlots = 'server.parallel_slots';
  static const String flashAttentionMode = 'server.flash_attention_mode';
  static const String useMmap = 'server.use_mmap';
  static const String llamaServerInstalledVersion =
      'server.llama_server_installed_version';
}
