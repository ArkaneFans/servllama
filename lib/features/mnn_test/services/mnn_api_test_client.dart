import 'dart:convert';
import 'dart:typed_data';

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

  Future<MnnApiTestResult> toolCall({
    required String baseUrl,
    String? model,
    String? apiKey,
    int maxTokens = 512,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.post<Object?>(
        '$baseUrl/v1/chat/completions',
        data: <String, Object?>{
          'model': model,
          'messages': const <Map<String, Object?>>[
            <String, Object?>{
              'role': 'user',
              'content': 'What time is it in Shanghai? Use the available tool.',
            },
          ],
          'tools': <Map<String, Object?>>[_timeTool],
          'tool_choice': <String, Object?>{
            'type': 'function',
            'function': const <String, Object?>{'name': 'get_current_time'},
          },
          'parallel_tool_calls': false,
          'stream': false,
          'max_tokens': maxTokens,
        },
        options: Options(headers: _headers(apiKey)),
      );
      final call = _firstToolCall(response.data);
      return MnnApiTestResult(
        label: 'Tool call /v1/chat/completions',
        output: _pretty(response.data),
        succeeded: response.statusCode == 200 && call != null,
        elapsedMs: stopwatch.elapsedMilliseconds,
        statusCode: response.statusCode,
        toolCallId: call?.$1,
        toolName: call?.$2,
        toolArguments: call?.$3,
      );
    } on DioException catch (error) {
      return _dioError(
        'Tool call /v1/chat/completions',
        error,
        stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<MnnApiTestResult> toolRoundTrip({
    required String baseUrl,
    String? model,
    String? apiKey,
    int maxTokens = 512,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final first = await _dio.post<Object?>(
        '$baseUrl/v1/chat/completions',
        data: <String, Object?>{
          'model': model,
          'messages': const <Map<String, Object?>>[
            <String, Object?>{
              'role': 'user',
              'content': 'What time is it in Shanghai? Use the available tool.',
            },
          ],
          'tools': <Map<String, Object?>>[_timeTool],
          'tool_choice': 'required',
          'parallel_tool_calls': false,
          'stream': false,
          'max_tokens': maxTokens,
        },
        options: Options(headers: _headers(apiKey)),
      );
      final firstMap = _jsonMap(first.data);
      final call = _firstToolCall(firstMap);
      if (call == null) {
        return MnnApiTestResult(
          label: 'Tool history round trip',
          output: _pretty(first.data),
          succeeded: false,
          elapsedMs: stopwatch.elapsedMilliseconds,
          statusCode: first.statusCode,
        );
      }
      final assistant =
          ((firstMap?['choices'] as List?)?.first as Map?)?['message'];
      final second = await _dio.post<Object?>(
        '$baseUrl/v1/chat/completions',
        data: <String, Object?>{
          'model': model,
          'messages': <Map<String, Object?>>[
            const <String, Object?>{
              'role': 'user',
              'content': 'What time is it in Shanghai? Use the available tool.',
            },
            Map<String, Object?>.from(assistant! as Map),
            <String, Object?>{
              'role': 'tool',
              'tool_call_id': call.$1,
              'content':
                  '{"city":"Shanghai","time":"10:30","timezone":"Asia/Shanghai"}',
            },
          ],
          'stream': false,
          'max_tokens': maxTokens,
        },
        options: Options(headers: _headers(apiKey)),
      );
      return MnnApiTestResult(
        label: 'Tool history round trip',
        output:
            'Tool call:\n${_pretty(first.data)}\n\nFinal response:\n${_pretty(second.data)}',
        succeeded: first.statusCode == 200 && second.statusCode == 200,
        elapsedMs: stopwatch.elapsedMilliseconds,
        statusCode: second.statusCode,
        toolCallId: call.$1,
        toolName: call.$2,
        toolArguments: call.$3,
      );
    } on DioException catch (error) {
      return _dioError(
        'Tool history round trip',
        error,
        stopwatch.elapsedMilliseconds,
      );
    }
  }

  Future<MnnApiTestResult> multimodal({
    required String baseUrl,
    required Uint8List imageBytes,
    String? model,
    String? apiKey,
    int maxTokens = 512,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.post<Object?>(
        '$baseUrl/v1/chat/completions',
        data: <String, Object?>{
          'model': model,
          'messages': <Map<String, Object?>>[
            <String, Object?>{
              'role': 'user',
              'content': <Map<String, Object?>>[
                const <String, Object?>{
                  'type': 'text',
                  'text': 'Describe the main object in this image.',
                },
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
          'stream': false,
          'max_tokens': maxTokens,
        },
        options: Options(headers: _headers(apiKey)),
      );
      final usage = _usage(response.data);
      return MnnApiTestResult(
        label: 'Multimodal apple.jpg',
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
        'Multimodal apple.jpg',
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

  (String, String, String)? _firstToolCall(Object? value) {
    final decoded = _jsonMap(value);
    final choices = decoded?['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final message = (choices.first as Map?)?['message'];
    final calls = (message as Map?)?['tool_calls'];
    if (calls is! List || calls.isEmpty) return null;
    final call = calls.first as Map?;
    final function = call?['function'] as Map?;
    final id = call?['id'];
    final name = function?['name'];
    final arguments = function?['arguments'];
    if (id is! String || name is! String || arguments is! String) return null;
    return (id, name, arguments);
  }

  Map<String, dynamic>? _jsonMap(Object? value) {
    Object? decoded = value;
    if (decoded is String) decoded = _decodeJsonOrNull(decoded);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
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

  static const Map<String, Object?> _timeTool = <String, Object?>{
    'type': 'function',
    'function': <String, Object?>{
      'name': 'get_current_time',
      'description': 'Get the current local time for a city.',
      'parameters': <String, Object?>{
        'type': 'object',
        'properties': <String, Object?>{
          'city': <String, Object?>{
            'type': 'string',
            'description': 'City name.',
          },
        },
        'required': <String>['city'],
        'additionalProperties': false,
      },
    },
  };
}
