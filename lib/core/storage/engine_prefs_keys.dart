class EnginePrefsKeys {
  const EnginePrefsKeys._();

  static const String activeEngine = 'engine.active';

  /// Last model the user picked for an engine, so restarting the runtime
  /// resumes where they left off instead of coming up empty.
  static String selectedModel(String engineStorageValue) =>
      'engine.$engineStorageValue.selected_model';
}
