import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:servllama/features/mnn_test/models/mnn_api_test_result.dart';

class MnnApiTestClient {
  MnnApiTestClient({Dio? dio}) : _dio = dio ?? Dio();

  static const String toolPrompt = '请查询上海现在的时间，并使用可用工具完成回答。';
  static const String multimodalPrompt = '请仔细观察这张图片，用中文说明图片中的主要物体、颜色和场景。';
  static const String toolName = 'get_current_time';

  static const Map<String, Object?> timeTool = <String, Object?>{
    'type': 'function',
    'function': <String, Object?>{
      'name': toolName,
      'description': '查询指定城市的当前时间',
      'parameters': <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'city': <String, Object?>{
            'type': 'string',
            'description': '城市名称，例如上海',
          },
        },
        'required': <String>['city'],
        'additionalProperties': false,
      },
    },
  };

  static const int maxDisplayedSseEvents = 256;
  static const int maxDisplayedSseBytes = 512 * 1024;

  final Dio _dio;
  CancelToken? _streamCancelToken;

  Future<MnnApiCallResult> getJsonCall({
    required String baseUrl,
    required String path,
    String? apiKey,
  }) async {
    final url = '$baseUrl$path';
    final headers = _headers(apiKey);
    final requestDisplay = displayRequest(
      method: 'GET',
      url: url,
      headers: headers,
      body: null,
    );
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get<Object?>(
        url,
        options: Options(headers: headers),
      );
      return MnnApiCallResult(
        exchange: MnnApiExchange(
          method: 'GET',
          url: url,
          requestDisplay: requestDisplay,
          responseDisplay: pretty(response.data),
          responseData: response.data,
          succeeded: response.statusCode == 200,
          elapsedMs: stopwatch.elapsedMilliseconds,
          statusCode: response.statusCode,
          contentType: response.headers.value('content-type'),
        ),
      );
    } on DioException catch (error) {
      return MnnApiCallResult(
        exchange: _errorExchange(
          method: 'GET',
          url: url,
          requestDisplay: requestDisplay,
          error: error,
          elapsedMs: stopwatch.elapsedMilliseconds,
        ),
      );
    }
  }

  Future<MnnApiTestResult> getJson({
    required String baseUrl,
    required String path,
    String? apiKey,
  }) async {
    final call = await getJsonCall(
      baseUrl: baseUrl,
      path: path,
      apiKey: apiKey,
    );
    return _resultFromCall('GET $path', call);
  }

  Future<MnnApiCallResult> postJson({
    required String baseUrl,
    required String path,
    required Object? body,
    String? apiKey,
  }) async {
    final url = '$baseUrl$path';
    final headers = _headers(apiKey);
    final requestDisplay = displayRequest(
      method: 'POST',
      url: url,
      headers: headers,
      body: body,
    );
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.post<Object?>(
        url,
        data: body,
        options: Options(headers: headers),
      );
      return MnnApiCallResult(
        exchange: MnnApiExchange(
          method: 'POST',
          url: url,
          requestDisplay: requestDisplay,
          responseDisplay: pretty(response.data),
          responseData: response.data,
          succeeded: response.statusCode == 200,
          elapsedMs: stopwatch.elapsedMilliseconds,
          statusCode: response.statusCode,
          contentType: response.headers.value('content-type'),
        ),
      );
    } on DioException catch (error) {
      return MnnApiCallResult(
        exchange: _errorExchange(
          method: 'POST',
          url: url,
          requestDisplay: requestDisplay,
          error: error,
          elapsedMs: stopwatch.elapsedMilliseconds,
        ),
      );
    }
  }

  Future<MnnApiTestResult> chat({
    required String baseUrl,
    required String prompt,
    String? model,
    String? apiKey,
    String? systemPrompt,
    double? temperature,
    double? topP,
    int maxTokens = 512,
  }) async {
    final body = <String, Object?>{
      'model': model,
      'messages': <Map<String, Object?>>[
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
          <String, Object?>{'role': 'system', 'content': systemPrompt.trim()},
        <String, Object?>{'role': 'user', 'content': prompt},
      ],
      'stream': false,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      'max_tokens': maxTokens,
    };
    final call = await postJson(
      baseUrl: baseUrl,
      path: '/v1/chat/completions',
      body: body,
      apiKey: apiKey,
    );
    final usage = _usage(call.responseData);
    return _resultFromCall(
      'POST /v1/chat/completions',
      call,
      promptTokens: usage.$1,
      completionTokens: usage.$2,
      totalTokens: usage.$3,
    );
  }

  Future<MnnApiTestResult> multimodal({
    required String baseUrl,
    required Uint8List imageBytes,
    String? model,
    String? apiKey,
    int maxTokens = 512,
  }) async {
    final call = await postJson(
      baseUrl: baseUrl,
      path: '/v1/chat/completions',
      body: _multimodalBody(
        model: model,
        imageBytes: imageBytes,
        stream: false,
        maxTokens: maxTokens,
      ),
      apiKey: apiKey,
    );
    final usage = _usage(call.responseData);
    return _resultFromCall(
      'Multimodal apple.jpg',
      call,
      promptTokens: usage.$1,
      completionTokens: usage.$2,
      totalTokens: usage.$3,
    );
  }

  Future<MnnApiTestResult> streamChat({
    required String baseUrl,
    required String prompt,
    required void Function(String text) onChunk,
    String? model,
    String? apiKey,
    String? systemPrompt,
    double? temperature,
    double? topP,
    int maxTokens = 512,
  }) {
    final body = <String, Object?>{
      'model': model,
      'messages': <Map<String, Object?>>[
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
          <String, Object?>{'role': 'system', 'content': systemPrompt.trim()},
        <String, Object?>{'role': 'user', 'content': prompt},
      ],
      'stream': true,
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      'max_tokens': maxTokens,
    };
    return _streamMessages(
      baseUrl: baseUrl,
      body: body,
      apiKey: apiKey,
      label: 'SSE /v1/chat/completions',
      onChunk: onChunk,
    );
  }

  Future<MnnApiTestResult> streamMultimodal({
    required String baseUrl,
    required Uint8List imageBytes,
    required void Function(String text) onChunk,
    String? model,
    String? apiKey,
    int maxTokens = 512,
  }) {
    return _streamMessages(
      baseUrl: baseUrl,
      body: _multimodalBody(
        model: model,
        imageBytes: imageBytes,
        stream: true,
        maxTokens: maxTokens,
      ),
      apiKey: apiKey,
      label: 'SSE Multimodal apple.jpg',
      onChunk: onChunk,
    );
  }

  Future<MnnApiTestResult> _streamMessages({
    required String baseUrl,
    required Map<String, Object?> body,
    required String? apiKey,
    required String label,
    required void Function(String text) onChunk,
  }) async {
    _streamCancelToken?.cancel('Superseded by a new stream request.');
    final cancelToken = CancelToken();
    _streamCancelToken = cancelToken;
    final url = '$baseUrl/v1/chat/completions';
    final headers = _headers(apiKey);
    final requestDisplay = displayRequest(
      method: 'POST',
      url: url,
      headers: headers,
      body: body,
    );
    final collected = StringBuffer();
    final events = <Object?>[];
    var omittedEvents = 0;
    var displayedEventBytes = 0;
    final stopwatch = Stopwatch()..start();
    int? firstTokenMs;
    var completed = false;
    try {
      final response = await _dio.post<ResponseBody>(
        url,
        data: body,
        options: Options(headers: headers, responseType: ResponseType.stream),
        cancelToken: cancelToken,
      );
      final responseBody = response.data;
      if (responseBody == null) {
        throw StateError('SSE response body is empty.');
      }
      await for (final line
          in responseBody.stream
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final trimmed = line.trimLeft();
        if (!trimmed.startsWith('data:')) continue;
        final data = trimmed.substring(5).trimLeft();
        if (data == '[DONE]') {
          completed = true;
          break;
        }
        final decoded = _decodeJsonOrNull(data);
        if (decoded == null) continue;
        final eventSize = utf8.encode(data).length;
        if (events.length < maxDisplayedSseEvents &&
            displayedEventBytes + eventSize <= maxDisplayedSseBytes) {
          events.add(decoded);
          displayedEventBytes += eventSize;
        } else {
          omittedEvents++;
        }
        if (decoded is! Map<String, dynamic>) continue;
        if (decoded['error'] is Map) {
          final exchange = _streamExchange(
            url: url,
            requestDisplay: requestDisplay,
            response: response,
            events: events,
            omittedEvents: omittedEvents,
            collected: collected.toString(),
            elapsedMs: stopwatch.elapsedMilliseconds,
            firstTokenMs: firstTokenMs,
            completed: false,
            succeeded: false,
            errorMessage: MnnApiTestClient.pretty(decoded['error']),
          );
          return _streamResult(label, exchange, collected.toString());
        }
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final choice = choices.first;
        if (choice is! Map) continue;
        final delta = choice['delta'];
        if (delta is! Map) continue;
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          firstTokenMs ??= stopwatch.elapsedMilliseconds;
          collected.write(content);
          onChunk(content);
        }
      }
      final exchange = _streamExchange(
        url: url,
        requestDisplay: requestDisplay,
        response: response,
        events: events,
        omittedEvents: omittedEvents,
        collected: collected.toString(),
        elapsedMs: stopwatch.elapsedMilliseconds,
        firstTokenMs: firstTokenMs,
        completed: completed,
        succeeded: completed && response.statusCode == 200,
        errorMessage: completed ? null : 'SSE stream ended before [DONE].',
      );
      return _streamResult(label, exchange, collected.toString());
    } on DioException catch (error) {
      final cancelled = CancelToken.isCancel(error);
      final exchange = _errorExchange(
        method: 'POST',
        url: url,
        requestDisplay: requestDisplay,
        error: error,
        elapsedMs: stopwatch.elapsedMilliseconds,
        firstTokenMs: firstTokenMs,
        sseEvents: events,
        sseCompleted: completed,
        cancelled: cancelled,
        responseDisplayOverride: MnnApiTestClient.pretty(<String, Object?>{
          'text': collected.toString(),
          'events': events,
          'omitted_events': omittedEvents,
          'done': completed,
          'cancelled': cancelled,
        }),
      );
      return _streamResult(label, exchange, collected.toString());
    } catch (error) {
      final exchange = MnnApiExchange(
        method: 'POST',
        url: url,
        requestDisplay: requestDisplay,
        responseDisplay: MnnApiTestClient.pretty(<String, Object?>{
          'text': collected.toString(),
          'events': events,
          'omitted_events': omittedEvents,
          'done': completed,
          'cancelled': false,
        }),
        succeeded: false,
        elapsedMs: stopwatch.elapsedMilliseconds,
        firstTokenMs: firstTokenMs,
        sseEventCount: events.length + omittedEvents,
        sseCompleted: completed,
        sseEvents: List<Object?>.unmodifiable(events),
        errorMessage: error.toString(),
      );
      return _streamResult(label, exchange, collected.toString());
    } finally {
      if (identical(_streamCancelToken, cancelToken)) {
        _streamCancelToken = null;
      }
    }
  }

  void cancelStream() {
    _streamCancelToken?.cancel('Cancelled from MNN test page.');
    _streamCancelToken = null;
  }

  void close() {
    cancelStream();
    _dio.close(force: true);
  }

  Map<String, String> _headers(String? apiKey) => <String, String>{
    'Content-Type': 'application/json',
    if (apiKey != null && apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
  };

  MnnApiTestResult _resultFromCall(
    String label,
    MnnApiCallResult call, {
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
  }) {
    final exchange = call.exchange;
    return MnnApiTestResult(
      label: label,
      output: exchange.responseDisplay,
      succeeded: exchange.succeeded,
      elapsedMs: exchange.elapsedMs,
      statusCode: exchange.statusCode,
      firstTokenMs: exchange.firstTokenMs,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      exchanges: <MnnApiExchange>[exchange],
      errorMessage: exchange.errorMessage,
    );
  }

  MnnApiTestResult _streamResult(
    String label,
    MnnApiExchange exchange,
    String text,
  ) {
    final output = text.isNotEmpty
        ? text
        : exchange.errorMessage ?? exchange.responseDisplay;
    return MnnApiTestResult(
      label: label,
      output: output,
      streamingText: text,
      succeeded: exchange.succeeded,
      elapsedMs: exchange.elapsedMs,
      statusCode: exchange.statusCode,
      firstTokenMs: exchange.firstTokenMs,
      cancelled: exchange.cancelled,
      exchanges: <MnnApiExchange>[exchange],
      errorMessage: exchange.errorMessage,
    );
  }

  MnnApiExchange _streamExchange({
    required String url,
    required String requestDisplay,
    required Response<ResponseBody> response,
    required List<Object?> events,
    required int omittedEvents,
    required String collected,
    required int elapsedMs,
    required int? firstTokenMs,
    required bool completed,
    required bool succeeded,
    required String? errorMessage,
  }) {
    return MnnApiExchange(
      method: 'POST',
      url: url,
      requestDisplay: requestDisplay,
      responseDisplay: MnnApiTestClient.pretty(<String, Object?>{
        'text': collected,
        'events': events,
        'omitted_events': omittedEvents,
        'done': completed,
      }),
      succeeded: succeeded,
      elapsedMs: elapsedMs,
      statusCode: response.statusCode,
      contentType: response.headers.value('content-type'),
      firstTokenMs: firstTokenMs,
      sseEventCount: events.length + omittedEvents,
      sseCompleted: completed,
      sseEvents: List<Object?>.unmodifiable(events),
      errorMessage: errorMessage,
    );
  }

  MnnApiExchange _errorExchange({
    required String method,
    required String url,
    required String requestDisplay,
    required DioException error,
    required int elapsedMs,
    int? firstTokenMs,
    List<Object?> sseEvents = const <Object?>[],
    bool sseCompleted = false,
    bool cancelled = false,
    String? responseDisplayOverride,
  }) {
    final response = error.response;
    final responseData = response?.data;
    final errorMessage = _errorMessage(error, cancelled: cancelled);
    return MnnApiExchange(
      method: method,
      url: url,
      requestDisplay: requestDisplay,
      responseDisplay:
          responseDisplayOverride ??
          (response == null
              ? error.message ?? error.toString()
              : '${response.statusCode}\n${pretty(responseData)}'),
      responseData: responseData,
      succeeded: false,
      elapsedMs: elapsedMs,
      statusCode: response?.statusCode,
      contentType: response?.headers.value('content-type'),
      firstTokenMs: firstTokenMs,
      sseEventCount: sseEvents.length,
      sseCompleted: sseCompleted,
      cancelled: cancelled,
      sseEvents: List<Object?>.unmodifiable(sseEvents),
      errorMessage: errorMessage,
    );
  }

  String _errorMessage(DioException error, {required bool cancelled}) {
    if (cancelled) {
      return '已取消：${error.message ?? error.toString()}';
    }
    final responseMap = asJsonMap(error.response?.data);
    final nestedError = responseMap?['error'];
    if (nestedError is Map && nestedError['message'] is String) {
      return nestedError['message'] as String;
    }
    if (responseMap?['message'] is String) {
      return responseMap!['message'] as String;
    }
    return error.message ?? error.toString();
  }

  (int?, int?, int?) _usage(Object? value) {
    final decoded = asJsonMap(value);
    final usage = decoded?['usage'];
    if (usage is! Map) return (null, null, null);
    return (
      (usage['prompt_tokens'] as num?)?.toInt(),
      (usage['completion_tokens'] as num?)?.toInt(),
      (usage['total_tokens'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> _multimodalBody({
    required String? model,
    required Uint8List imageBytes,
    required bool stream,
    required int maxTokens,
  }) {
    return <String, Object?>{
      'model': model,
      'messages': <Map<String, Object?>>[
        <String, Object?>{
          'role': 'user',
          'content': <Map<String, Object?>>[
            <String, Object?>{'type': 'text', 'text': multimodalPrompt},
            <String, Object?>{
              'type': 'image_url',
              'image_url': <String, Object?>{
                'url': 'data:image/jpeg;base64,${base64Encode(imageBytes)}',
                'detail': 'auto',
              },
            },
          ],
        },
      ],
      'stream': stream,
      'max_tokens': maxTokens,
    };
  }

  String displayRequest({
    required String method,
    required String url,
    required Map<String, String> headers,
    required Object? body,
  }) {
    return pretty(<String, Object?>{
      'method': method,
      'url': url,
      'headers': headers,
      'body': body ?? '<empty>',
    });
  }

  static Map<String, dynamic>? asJsonMap(Object? value) {
    Object? decoded = value;
    if (decoded is String) decoded = _decodeJsonOrNull(decoded);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  static String pretty(Object? value) {
    if (value is String) {
      final decoded = _decodeJsonOrNull(value);
      if (decoded != null) {
        value = decoded;
      }
    }
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value?.toString() ?? 'null';
    }
  }

  static Object? _decodeJsonOrNull(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }
}
