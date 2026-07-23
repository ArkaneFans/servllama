import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:servllama/features/mnn_test/models/mnn_api_test_result.dart';

class MnnApiTestClient {
  MnnApiTestClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  CancelToken? _streamCancelToken;

  Future<MnnApiTestResult> getJson({
    required String baseUrl,
    required String path,
    String? apiKey,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get<Object?>(
        '$baseUrl$path',
        options: Options(headers: _headers(apiKey)),
      );
      return MnnApiTestResult(
        label: 'GET $path',
        output: _pretty(response.data),
        succeeded: response.statusCode == 200,
        elapsedMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
      );
    } on DioException catch (error) {
      return _dioError('GET $path', error, stopwatch.elapsedMilliseconds);
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
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.post<Object?>(
        '$baseUrl/v1/chat/completions',
        data: <String, Object?>{
          'model': model,
          'messages': <Map<String, String>>[
            if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
              <String, String>{
                'role': 'system',
                'content': systemPrompt.trim(),
              },
            <String, String>{'role': 'user', 'content': prompt},
          ],
          'stream': false,
          if (temperature != null) 'temperature': temperature,
          if (topP != null) 'top_p': topP,
          'max_tokens': maxTokens,
        },
        options: Options(headers: _headers(apiKey)),
      );
      final usage = _usage(response.data);
      return MnnApiTestResult(
        label: 'POST /v1/chat/completions',
        output: _pretty(response.data),
        succeeded: response.statusCode == 200,
        elapsedMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        promptTokens: usage.$1,
        completionTokens: usage.$2,
        totalTokens: usage.$3,
      );
    } on DioException catch (error) {
      return _dioError(
        'POST /v1/chat/completions',
        error,
        stopwatch.elapsedMilliseconds,
      );
    }
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
  }) async {
    _streamCancelToken?.cancel('Superseded by a new stream request.');
    final cancelToken = CancelToken();
    _streamCancelToken = cancelToken;
    final collected = StringBuffer();
    final stopwatch = Stopwatch()..start();
    int? firstTokenMs;
    try {
      final response = await _dio.post<ResponseBody>(
        '$baseUrl/v1/chat/completions',
        data: <String, Object?>{
          'model': model,
          'messages': <Map<String, String>>[
            if (systemPrompt != null && systemPrompt.trim().isNotEmpty)
              <String, String>{
                'role': 'system',
                'content': systemPrompt.trim(),
              },
            <String, String>{'role': 'user', 'content': prompt},
          ],
          'stream': true,
          if (temperature != null) 'temperature': temperature,
          if (topP != null) 'top_p': topP,
          'max_tokens': maxTokens,
        },
        options: Options(
          headers: _headers(apiKey),
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );
      final body = response.data;
      if (body == null) throw StateError('SSE response body is empty.');
      await for (final line
          in body.stream
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6);
        if (data == '[DONE]') break;
        final decoded = _decodeJsonOrNull(data);
        if (decoded is! Map<String, dynamic>) continue;
        if (decoded['error'] is Map) {
          return MnnApiTestResult(
            label: 'SSE /v1/chat/completions',
            output: _pretty(decoded),
            succeeded: false,
            elapsedMs: stopwatch.elapsedMilliseconds,
            statusCode: response.statusCode,
            firstTokenMs: firstTokenMs,
          );
        }
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final choice = choices.first;
        if (choice is! Map<String, dynamic>) continue;
        final delta = choice['delta'];
        if (delta is! Map<String, dynamic>) continue;
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          firstTokenMs ??= stopwatch.elapsedMilliseconds;
          collected.write(content);
          onChunk(content);
        }
      }
      return MnnApiTestResult(
        label: 'SSE /v1/chat/completions',
        output: collected.toString(),
        succeeded: true,
        elapsedMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        firstTokenMs: firstTokenMs,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return MnnApiTestResult(
          label: 'SSE /v1/chat/completions',
          output: '${collected.toString()}\n[cancelled]',
          succeeded: false,
          elapsedMs: stopwatch.elapsedMilliseconds,
          firstTokenMs: firstTokenMs,
        );
      }
      return _dioError(
        'SSE /v1/chat/completions',
        error,
        stopwatch.elapsedMilliseconds,
        firstTokenMs: firstTokenMs,
      );
    } finally {
      if (identical(_streamCancelToken, cancelToken)) _streamCancelToken = null;
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

  MnnApiTestResult _dioError(
    String label,
    DioException error,
    int elapsedMs, {
    int? firstTokenMs,
  }) {
    final response = error.response;
    return MnnApiTestResult(
      label: label,
      output: response == null
          ? error.message ?? error.toString()
          : '${response.statusCode}\n${_pretty(response.data)}',
      succeeded: false,
      elapsedMs: elapsedMs,
      statusCode: response?.statusCode,
      firstTokenMs: firstTokenMs,
    );
  }

  (int?, int?, int?) _usage(Object? value) {
    Object? decoded = value;
    if (decoded is String) {
      decoded = _decodeJsonOrNull(decoded);
    }
    if (decoded is! Map) return (null, null, null);
    final usage = decoded['usage'];
    if (usage is! Map) return (null, null, null);
    return (
      (usage['prompt_tokens'] as num?)?.toInt(),
      (usage['completion_tokens'] as num?)?.toInt(),
      (usage['total_tokens'] as num?)?.toInt(),
    );
  }

  Object? _decodeJsonOrNull(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  String _pretty(Object? value) {
    if (value is String) {
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(value));
      } catch (_) {
        return value;
      }
    }
    return const JsonEncoder.withIndent('  ').convert(value);
  }
}
