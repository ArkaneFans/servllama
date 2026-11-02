import 'package:dio/dio.dart';

/// Reads the running llama.cpp server's actual per-slot context capacity.
///
/// The caller supplies its local runtime endpoint, never a remote provider or
/// the MNN endpoint. Configured launch settings are not a reliable substitute:
/// they may have changed since launch and can represent a shared context pool.
class ContextCapacityClient {
  ContextCapacityClient({Dio? dio})
    : _dio = dio ?? Dio(),
      _ownsDio = dio == null;

  static const _timeout = Duration(seconds: 3);

  final Dio _dio;
  final bool _ownsDio;

  Future<int?> fetchLlamaCapacity({
    required String baseUrl,
    required String apiKey,
  }) async {
    try {
      final key = apiKey.trim();
      final endpoint = '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/props';
      final options = Options(
        method: 'GET',
        responseType: ResponseType.json,
        headers: {if (key.isNotEmpty) 'Authorization': 'Bearer $key'},
        sendTimeout: _timeout,
        receiveTimeout: _timeout,
        followRedirects: false,
        maxRedirects: 0,
        validateStatus: (_) => true,
      ).compose(_dio.options, endpoint)..connectTimeout = _timeout;
      final response = await _dio.fetch<Object?>(options);
      if (response.statusCode != 200) return null;
      return parseLlamaCapacity(response.data);
    } catch (_) {
      // Capacity is optional display metadata. A failed probe must not break
      // chat, fall back to a guessed limit, or expose request credentials.
      return null;
    }
  }

  /// `/props.default_generation_settings.n_ctx` is already per slot; do not
  /// divide it by `/props.total_slots` (see bundled llama-server-README.md).
  static int? parseLlamaCapacity(Object? value) {
    if (value is! Map) return null;
    final settings = value['default_generation_settings'];
    if (settings is! Map) return null;
    final count = settings['n_ctx'];
    if (count is! num || !count.isFinite || count <= 0) return null;
    final tokens = count.toInt();
    return tokens == count ? tokens : null;
  }

  void dispose() {
    if (_ownsDio) _dio.close(force: true);
  }
}
