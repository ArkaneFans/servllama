import 'package:dio/dio.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';

/// Model state as reported by `llama-server`'s `/models` endpoint.
class LlamaServerModelState {
  const LlamaServerModelState({required this.id, required this.isLoaded});

  final String id;
  final bool isLoaded;
}

/// Core-level control surface for the `llama-server` child process. The chat
/// feature owns its own client for completions; this one only covers the
/// lifecycle calls the engine orchestrator needs, so `lib/core` never has to
/// reach into `lib/features`.
class LlamaServerControlClient {
  LlamaServerControlClient({Dio? dio, ServerLaunchSettingsLoader? settingsLoader})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 20),
              validateStatus: (_) => true,
            ),
          ),
      _settingsLoader = settingsLoader ?? ServerLaunchSettingsLoader();

  static const Duration modelLoadTimeout = Duration(seconds: 120);
  static const Duration _pollInterval = Duration(milliseconds: 500);

  final Dio _dio;
  final ServerLaunchSettingsLoader _settingsLoader;

  String _baseUrl = 'http://127.0.0.1:8080';

  void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }

  /// Polls `/models` until the server answers or [timeout] elapses. This is
  /// the readiness gate after spawning the process — the port binds before
  /// the HTTP stack is actually serving.
  Future<bool> waitUntilReachable({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (await _ping()) {
        return true;
      }
      await Future<void>.delayed(_pollInterval);
    }
    return false;
  }

  Future<List<LlamaServerModelState>> fetchModels() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_baseUrl/models',
      options: Options(headers: await _headers()),
    );
    final data = response.data?['data'];
    if (response.statusCode != 200 || data is! List) {
      return const <LlamaServerModelState>[];
    }
    final models = <LlamaServerModelState>[];
    for (final item in data) {
      if (item is! Map) {
        continue;
      }
      final id = '${item['id'] ?? ''}'.trim();
      if (id.isEmpty) {
        continue;
      }
      final status = (item['status'] as Map?)?['value']?.toString() ?? '';
      models.add(
        LlamaServerModelState(id: id, isLoaded: status == 'loaded'),
      );
    }
    return models;
  }

  /// Asks the server to load [modelId] and waits until `/models` reports it
  /// loaded. Returns false on timeout or an error status.
  Future<bool> loadModel(String modelId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/models/load',
      data: <String, dynamic>{'model': modelId},
      options: Options(headers: await _headers()),
    );
    if (response.statusCode != 200 && response.statusCode != 202) {
      return false;
    }

    final deadline = DateTime.now().add(modelLoadTimeout);
    while (DateTime.now().isBefore(deadline)) {
      final models = await fetchModels();
      for (final model in models) {
        if (model.id == modelId && model.isLoaded) {
          return true;
        }
      }
      await Future<void>.delayed(_pollInterval);
    }
    return false;
  }

  Future<void> unloadModel(String modelId) async {
    await _dio.post<Map<String, dynamic>>(
      '$_baseUrl/models/unload',
      data: <String, dynamic>{'model': modelId},
      options: Options(headers: await _headers()),
    );
  }

  Future<bool> _ping() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/models',
        options: Options(
          headers: await _headers(),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> _headers() async {
    try {
      final settings = await _settingsLoader.load();
      final apiKey = settings.apiKey.trim();
      if (apiKey.isEmpty) {
        return const <String, String>{};
      }
      return <String, String>{'Authorization': 'Bearer $apiKey'};
    } catch (_) {
      return const <String, String>{};
    }
  }
}
