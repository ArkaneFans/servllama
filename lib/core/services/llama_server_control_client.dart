import 'package:dio/dio.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';

/// Readiness probe for the model-specific `llama-server` child process.
class LlamaServerControlClient {
  LlamaServerControlClient({
    Dio? dio,
    ServerLaunchSettingsLoader? settingsLoader,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 5),
               receiveTimeout: const Duration(seconds: 20),
               validateStatus: (_) => true,
             ),
           ),
       _settingsLoader = settingsLoader ?? ServerLaunchSettingsLoader();

  static const Duration serverReadyTimeout = Duration(minutes: 5);
  static const Duration _pollInterval = Duration(milliseconds: 500);

  final Dio _dio;
  final ServerLaunchSettingsLoader _settingsLoader;

  String _baseUrl = 'http://127.0.0.1:8080';

  void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }

  /// `/health` returns 503 while the model is loading and 200 once requests
  /// can be served. [shouldContinue] lets cancellation and process exit stop
  /// the poll immediately instead of waiting for the full timeout.
  Future<bool> waitUntilReady({
    Duration timeout = serverReadyTimeout,
    bool Function()? shouldContinue,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (shouldContinue != null && !shouldContinue()) {
        return false;
      }
      if (await _ping()) {
        return true;
      }
      await Future<void>.delayed(_pollInterval);
    }
    return false;
  }

  Future<bool> _ping() async {
    try {
      final response = await _dio.get<Object?>(
        '$_baseUrl/health',
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
