import 'dart:async';

import 'package:dio/dio.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';
import 'package:servllama/features/downloads/services/model_hub_client.dart';

/// Resolves the "auto" Hugging Face route by timing both public API origins
/// in parallel. The winner is cached briefly so every file in one task uses a
/// stable origin without repeatedly probing the network.
class HuggingFaceRouteResolver {
  HuggingFaceRouteResolver({Dio? dio}) : _dio = dio ?? _defaultDio();

  final Dio _dio;
  String? _cachedHost;
  DateTime? _cachedAt;

  static const Duration _cacheLifetime = Duration(minutes: 10);

  static Dio _defaultDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
      validateStatus: (_) => true,
    ),
  );

  Future<String> resolve(HuggingFaceRoute route) async {
    switch (route) {
      case HuggingFaceRoute.official:
        return HuggingFaceHubClient.officialHost;
      case HuggingFaceRoute.mirror:
        return HuggingFaceHubClient.mirrorHost;
      case HuggingFaceRoute.auto:
        final cachedAt = _cachedAt;
        if (_cachedHost != null &&
            cachedAt != null &&
            DateTime.now().difference(cachedAt) < _cacheLifetime) {
          return _cachedHost!;
        }
        final probes = await Future.wait<_RouteProbe>(<Future<_RouteProbe>>[
          _probe(HuggingFaceHubClient.officialHost),
          _probe(HuggingFaceHubClient.mirrorHost),
        ]);
        final reachable =
            probes
                .where((probe) => probe.elapsed != null)
                .toList(growable: false)
              ..sort((left, right) => left.elapsed!.compareTo(right.elapsed!));
        _cachedHost = reachable.isEmpty
            ? HuggingFaceHubClient.officialHost
            : reachable.first.host;
        _cachedAt = DateTime.now();
        return _cachedHost!;
    }
  }

  Future<_RouteProbe> _probe(String host) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get<dynamic>(
        '$host/api/models',
        queryParameters: const <String, dynamic>{'limit': 1},
      );
      stopwatch.stop();
      final status = response.statusCode ?? 0;
      return _RouteProbe(
        host,
        status >= 200 && status < 500 ? stopwatch.elapsed : null,
      );
    } on DioException catch (_) {
      stopwatch.stop();
      return _RouteProbe(host, null);
    }
  }
}

class _RouteProbe {
  const _RouteProbe(this.host, this.elapsed);

  final String host;
  final Duration? elapsed;
}
