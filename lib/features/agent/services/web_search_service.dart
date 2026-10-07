import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/agent/models/web_search.dart';

/// Fetches only the selected search provider. Result URLs are data, never fetched.
class WebSearchService {
  WebSearchService({
    Dio? dio,
    AppLogger? logger,
    this.timeout = const Duration(seconds: 20),
  }) : _dio = dio ?? Dio(),
       _ownsDio = dio == null,
       _logger = logger ?? AppLogger.instance;

  final Dio _dio;
  final bool _ownsDio;
  final AppLogger _logger;
  final Duration timeout;
  static const maxResponseBytes = 2 * 1024 * 1024;

  Future<WebSearchResult> search(
    String query, {
    required WebSearchOptions options,
    required CancelToken cancelToken,
    int? limit,
    String? runId,
    String? callId,
  }) async {
    options.validate();
    query = query.trim();
    if (query.isEmpty ||
        query.length > 512 ||
        (limit != null && (limit < 1 || limit > 10))) {
      throw const FormatException('Invalid web search arguments');
    }
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    final resultLimit = (limit ?? options.maxResults).clamp(
      1,
      options.maxResults,
    );
    final requestToken = CancelToken();
    var finished = false;
    unawaited(
      cancelToken.whenCancel.then((_) {
        if (!finished) requestToken.cancel('search cancelled');
      }),
    );
    final watch = Stopwatch()..start();
    final fields = <String, Object?>{
      'run': runId,
      'call': callId,
      'provider': options.provider.name,
      'query_chars': query.length,
      'limit': resultLimit,
    };
    _logger.event(
      'agent.search.started',
      channel: LogChannel.agent,
      fields: fields,
    );
    try {
      final items =
          await _search(
            options.provider,
            query,
            resultLimit,
            requestToken,
          ).timeout(
            timeout,
            onTimeout: () {
              requestToken.cancel('search timeout');
              throw const WebSearchException(WebSearchFailure.timeout);
            },
          );
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      _logger.event(
        'agent.search.finished',
        channel: LogChannel.agent,
        fields: {
          ...fields,
          'outcome': 'completed',
          'results': items.length,
          'elapsed_ms': watch.elapsedMilliseconds,
        },
      );
      return WebSearchResult(
        provider: options.provider,
        query: query,
        retrievedAt: DateTime.now().toUtc(),
        items: items,
      );
    } catch (error) {
      final failure = error is WebSearchException
          ? error
          : WebSearchException(
              error is DioException &&
                      const {
                        DioExceptionType.connectionTimeout,
                        DioExceptionType.receiveTimeout,
                        DioExceptionType.sendTimeout,
                      }.contains(error.type)
                  ? WebSearchFailure.timeout
                  : WebSearchFailure.unavailable,
              statusCode: error is DioException
                  ? error.response?.statusCode
                  : null,
            );
      _logger.event(
        'agent.search.finished',
        channel: LogChannel.agent,
        level: cancelToken.isCancelled ? LogLevel.info : LogLevel.warning,
        fields: {
          ...fields,
          'outcome': cancelToken.isCancelled ? 'cancelled' : 'failed',
          if (!cancelToken.isCancelled) 'reason': failure.reason.name,
          'http_status': failure.statusCode,
          'elapsed_ms': watch.elapsedMilliseconds,
        },
      );
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      throw failure;
    } finally {
      finished = true;
      requestToken.cancel('search finished');
    }
  }

  Future<List<WebSearchItem>> _search(
    WebSearchProvider provider,
    String query,
    int limit,
    CancelToken token,
  ) async {
    var uri = switch (provider) {
      WebSearchProvider.bing => Uri.https('www.bing.com', '/search', {
        'q': query,
      }),
      WebSearchProvider.duckduckgo => Uri.https(
        'html.duckduckgo.com',
        '/html/',
        {'q': query},
      ),
    };
    for (var redirects = 0; redirects <= 3; redirects++) {
      final response = await _dio.getUri<ResponseBody>(
        uri,
        cancelToken: token,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          receiveTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 8),
          validateStatus: (_) => true,
          headers: const {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml',
          },
        ),
      );
      final body = response.data!;
      final status = response.statusCode ?? 0;
      if (const {301, 302, 303, 307, 308}.contains(status)) {
        await body.stream.listen(null).cancel();
        final location = response.headers.value('location');
        final next = location == null ? null : uri.resolve(location);
        if (next == null ||
            next.scheme != 'https' ||
            next.userInfo.isNotEmpty ||
            next.port != 443 ||
            !_providerHost(provider, next.host)) {
          throw const WebSearchException(WebSearchFailure.invalidResponse);
        }
        uri = next;
        continue;
      }
      if (status != 200) {
        await body.stream.listen(null).cancel();
        throw WebSearchException(switch (status) {
          429 => WebSearchFailure.rateLimited,
          202 || 403 => WebSearchFailure.challenge,
          _ => WebSearchFailure.unavailable,
        }, statusCode: status);
      }
      final type = response.headers.value('content-type')?.toLowerCase();
      if (type != null &&
          !type.contains('text/html') &&
          !type.contains('application/xhtml+xml')) {
        await body.stream.listen(null).cancel();
        throw const WebSearchException(WebSearchFailure.invalidResponse);
      }
      final declaredSize = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      if (declaredSize != null && declaredSize > maxResponseBytes) {
        await body.stream.listen(null).cancel();
        throw const WebSearchException(WebSearchFailure.tooLarge);
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in body.stream) {
        if (token.isCancelled) throw token.cancelError!;
        if (bytes.length + chunk.length > maxResponseBytes) {
          throw const WebSearchException(WebSearchFailure.tooLarge);
        }
        bytes.add(chunk);
      }
      if (token.isCancelled) throw token.cancelError!;
      return compute(_parseResults, (
        provider: provider,
        html: utf8.decode(bytes.takeBytes(), allowMalformed: true),
        limit: limit,
      ));
    }
    throw const WebSearchException(WebSearchFailure.invalidResponse);
  }

  void dispose() {
    if (_ownsDio) _dio.close(force: true);
  }
}

bool _providerHost(WebSearchProvider provider, String host) {
  final domain = provider == WebSearchProvider.bing
      ? 'bing.com'
      : 'duckduckgo.com';
  return host == domain || host.endsWith('.$domain');
}

List<WebSearchItem> _parseResults(
  ({WebSearchProvider provider, String html, int limit}) input,
) {
  final document = html_parser.parse(input.html);
  if (document.querySelector(
        '#challenge-form, .anomaly-modal, #b_captcha, .b_captcha, '
        'form[action*="anomaly.js"], iframe[src*="captcha"]',
      ) !=
      null) {
    throw const WebSearchException(WebSearchFailure.challenge);
  }
  for (final node in document.querySelectorAll('script, style, noscript')) {
    node.remove();
  }
  final bing = input.provider == WebSearchProvider.bing;
  final rows = document.querySelectorAll(bing ? 'li.b_algo' : '.result');
  final seen = <String>{};
  final items = <WebSearchItem>[];
  var outputBytes = 0;
  for (final row in rows) {
    if (row.classes.contains('result--ad')) continue;
    final link = row.querySelector(bing ? 'h2 a' : '.result__a');
    final title = _text(link?.text ?? '', 240);
    final url = _resultUrl(input.provider, link?.attributes['href'] ?? '');
    if (title.isEmpty || url == null || !seen.add(url)) continue;
    final item = WebSearchItem(
      title: title,
      url: url,
      snippet: _text(
        row
                .querySelector(
                  bing ? '.b_caption p, .b_algoSlug' : '.result__snippet',
                )
                ?.text ??
            '',
        800,
      ),
    );
    final size = utf8.encode(jsonEncode(item.toJson())).length;
    // Leave room for query/metadata within the existing tool receipt budget.
    if (outputBytes + size > 12 * 1024) break;
    items.add(item);
    outputBytes += size;
    if (items.length >= input.limit) break;
  }
  if (items.isEmpty &&
      document.querySelector(
            bing ? '.b_no' : '.no-results, .result--no-result',
          ) ==
          null) {
    // A block page or changed markup must not masquerade as a successful search.
    throw const WebSearchException(WebSearchFailure.invalidResponse);
  }
  return items;
}

String _text(String value, int limit) => String.fromCharCodes(
  value.replaceAll(RegExp(r'\s+'), ' ').trim().runes.take(limit),
);

String? _resultUrl(WebSearchProvider provider, String raw) {
  if (raw.isEmpty) return null;
  try {
    var uri = Uri.parse(raw.trim());
    if (!uri.hasScheme) {
      uri = Uri.https(
        provider == WebSearchProvider.bing ? 'www.bing.com' : 'duckduckgo.com',
      ).resolveUri(uri);
    }
    if (_providerHost(provider, uri.host)) {
      if (provider == WebSearchProvider.duckduckgo &&
          uri.queryParameters.containsKey('uddg')) {
        uri = Uri.parse(uri.queryParameters['uddg']!);
      } else if (provider == WebSearchProvider.bing && uri.path == '/ck/a') {
        final encoded = uri.queryParameters['u'];
        if (encoded == null || !encoded.startsWith('a1')) return null;
        uri = Uri.parse(
          utf8.decode(
            base64Url.decode(base64Url.normalize(encoded.substring(2))),
          ),
        );
      }
    }
    if (!const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    final url = uri.removeFragment().toString();
    return url.length <= 2048 ? url : null;
  } on FormatException {
    return null;
  }
}
