import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/core/network/server_sent_events.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/chat/services/reasoning_request.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/stream_chunk.dart';
import 'package:servllama/features/chat/services/chat_stream_decoder.dart';

/// One request/response round only. Tool scheduling belongs to ChatRunner.
class ChatProtocolClient {
  static const _anthropicFallbackMaxTokens = 32768;

  ChatProtocolClient({Dio? dio, AppLogger? logger})
    : _logger = logger ?? AppLogger.instance,
      dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 3),
              sendTimeout: const Duration(seconds: 30),
              followRedirects: false,
            ),
          );
  final Dio dio;
  final AppLogger _logger;
  Map<String, String> headers(AiConnection c, String key) {
    LogRedactor.remember(key);
    return {
      'Content-Type': 'application/json',
      if (c.protocol == AiProtocol.anthropic) 'anthropic-version': '2023-06-01',
      if (key.isNotEmpty)
        switch (c.protocol) {
          AiProtocol.openai => 'Authorization',
          AiProtocol.anthropic => 'x-api-key',
          AiProtocol.gemini => 'x-goog-api-key',
        }: c.protocol == AiProtocol.openai
            ? 'Bearer $key'
            : key,
    };
  }

  String _base(AiConnection c) => c.baseUrl.replaceFirst(RegExp(r'/+$'), '');
  Future<List<String>> listModels(
    AiConnection c,
    String key, {
    CancelToken? cancelToken,
  }) async {
    final watch = Stopwatch()..start();
    final fields = {'connection': c.id, 'protocol': c.protocol.name};
    _logger.event(
      'client.models.started',
      channel: LogChannel.client,
      fields: fields,
    );
    try {
      c.validate();
      final found = <String>{};
      final seenCursors = <String>{};
      String? cursor;
      for (var page = 0; ; page++) {
        if (page >= 32) {
          throw const FormatException('Model list exceeds page limit');
        }
        final response = await dio.get<dynamic>(
          '${_base(c)}/models',
          queryParameters: cursor == null
              ? null
              : {
                  c.protocol == AiProtocol.gemini ? 'pageToken' : 'after_id':
                      cursor,
                },
          options: Options(
            headers: headers(c, key),
            receiveTimeout: const Duration(seconds: 30),
          ),
          cancelToken: cancelToken,
        );
        final body = response.data;
        if (body is! Map || (body['data'] ?? body['models']) is! List) {
          throw const FormatException('Invalid model list response');
        }
        for (final row in (body['data'] ?? body['models']) as List) {
          if (row is! Map) continue;
          final value = row['id'] ?? row['name'];
          if (value is! String) continue;
          final id = c.protocol == AiProtocol.gemini
              ? value.replaceFirst(RegExp(r'^models/'), '').trim()
              : value.trim();
          if (id.isNotEmpty && id.length <= 512) found.add(id);
        }
        if (found.length > 5000) {
          throw const FormatException('Model list exceeds size limit');
        }
        cursor = switch (c.protocol) {
          AiProtocol.gemini => body['nextPageToken'] as String?,
          AiProtocol.anthropic when body['has_more'] == true =>
            body['last_id'] as String?,
          _ => null,
        };
        if (c.protocol == AiProtocol.anthropic &&
            body['has_more'] == true &&
            (cursor == null || cursor.isEmpty)) {
          throw const FormatException(
            'Model list is missing its next page cursor',
          );
        }
        if (cursor == null || cursor.isEmpty) break;
        if (!seenCursors.add(cursor)) {
          throw const FormatException('Model list repeated a page cursor');
        }
      }
      final models = found.toList()..sort();
      _logger.event(
        'client.models.completed',
        channel: LogChannel.client,
        fields: {
          ...fields,
          'count': models.length,
          'elapsed_ms': watch.elapsedMilliseconds,
        },
      );
      return models;
    } catch (error) {
      _logger.event(
        'client.models.failed',
        channel: LogChannel.client,
        level: error is DioException && CancelToken.isCancel(error)
            ? LogLevel.info
            : LogLevel.error,
        fields: {
          ...fields,
          'elapsed_ms': watch.elapsedMilliseconds,
          ...AppLogger.errorFields(error),
        },
      );
      rethrow;
    }
  }

  Future<void> test(
    AiConnection c,
    String key,
    String model, {
    CancelToken? cancelToken,
  }) async {
    final watch = Stopwatch()..start();
    final fields = {'connection': c.id, 'protocol': c.protocol.name};
    _logger.event(
      'client.connection_test.started',
      channel: LogChannel.client,
      fields: fields,
    );
    try {
      if (model.isEmpty) {
        await listModels(c, key, cancelToken: cancelToken);
      } else {
        await complete(
          c,
          key,
          model,
          [const AiTurn(role: 'user', text: 'Reply OK')],
          cancelToken: cancelToken ?? CancelToken(),
          maxTokens: 32,
        ).drain<void>();
      }
      _logger.event(
        'client.connection_test.completed',
        channel: LogChannel.client,
        fields: {...fields, 'elapsed_ms': watch.elapsedMilliseconds},
      );
    } catch (error) {
      _logger.event(
        'client.connection_test.failed',
        channel: LogChannel.client,
        level: error is DioException && CancelToken.isCancel(error)
            ? LogLevel.info
            : LogLevel.error,
        fields: {
          ...fields,
          'elapsed_ms': watch.elapsedMilliseconds,
          ...AppLogger.errorFields(error),
        },
      );
      rethrow;
    }
  }

  Map<String, dynamic> requestBody(
    AiConnection c,
    String model,
    List<AiTurn> turns, {
    String system = '',
    List<AiTool> tools = const [],
    double temperature = .7,
    int? maxTokens,
    ReasoningLevel reasoningLevel = ReasoningLevel.auto,
  }) {
    final body = _requestBody(
      c,
      model,
      turns,
      system: system,
      tools: tools,
      temperature: temperature,
      maxTokens: maxTokens,
    );
    applyReasoningRequest(body, c, model, reasoningLevel);
    return body;
  }

  Map<String, dynamic> _requestBody(
    AiConnection c,
    String model,
    List<AiTurn> turns, {
    String system = '',
    List<AiTool> tools = const [],
    double temperature = .7,
    int? maxTokens,
  }) {
    switch (c.protocol) {
      case AiProtocol.openai:
        return {
          'model': model,
          'stream': true,
          'stream_options': {'include_usage': true},
          'temperature': temperature,
          if (maxTokens != null) 'max_tokens': maxTokens,
          'messages': [
            if (system.isNotEmpty) {'role': 'system', 'content': system},
            ...turns.map(_openaiTurn),
          ],
          if (tools.isNotEmpty)
            'tools': tools
                .map(
                  (t) => {
                    'type': 'function',
                    'function': {
                      'name': t.name,
                      'description': t.description,
                      'parameters': t.schema,
                    },
                  },
                )
                .toList(),
        };
      case AiProtocol.anthropic:
        final messages = <Map<String, dynamic>>[];
        for (final t in turns) {
          final role = t.role == 'tool' ? 'user' : t.role;
          final parts = _anthropicParts(t);
          if (messages.isNotEmpty && messages.last['role'] == role) {
            (messages.last['content'] as List).addAll(parts);
          } else {
            messages.add({'role': role, 'content': parts});
          }
        }
        return {
          'model': model,
          'stream': true,
          // Anthropic requires this field even when chat itself has no limit.
          'max_tokens': maxTokens ?? _anthropicFallbackMaxTokens,
          'temperature': temperature,
          if (system.isNotEmpty) 'system': system,
          'messages': messages,
          if (tools.isNotEmpty)
            'tools': tools
                .map(
                  (t) => {
                    'name': t.name,
                    'description': t.description,
                    'input_schema': t.schema,
                  },
                )
                .toList(),
        };
      case AiProtocol.gemini:
        return {
          'contents': turns
              .map(
                (t) => {
                  'role': t.role == 'assistant' ? 'model' : 'user',
                  'parts': _geminiParts(t),
                },
              )
              .toList(),
          if (system.isNotEmpty)
            'systemInstruction': {
              'parts': [
                {'text': system},
              ],
            },
          'generationConfig': <String, dynamic>{
            'temperature': temperature,
            if (maxTokens != null) 'maxOutputTokens': maxTokens,
          },
          if (tools.isNotEmpty)
            'tools': [
              {
                'functionDeclarations': tools
                    .map(
                      (t) => {
                        'name': t.name,
                        'description': t.description,
                        'parameters': t.schema,
                      },
                    )
                    .toList(),
              },
            ],
        };
    }
  }

  Map<String, dynamic> _openaiTurn(AiTurn t) => {
    'role': t.role,
    'content': t.images.isEmpty
        ? t.text
        : [
            if (t.text.isNotEmpty) {'type': 'text', 'text': t.text},
            ...t.images.map(
              (i) => {
                'type': 'image_url',
                'image_url': {'url': 'data:${i.mime};base64,${i.base64}'},
              },
            ),
          ],
    if (t.toolCallId != null) 'tool_call_id': t.toolCallId,
    if (t.calls.isNotEmpty)
      'tool_calls': t.calls
          .map(
            (c) => {
              'id': c.id,
              'type': 'function',
              'function': {
                'name': c.name,
                'arguments': jsonEncode(c.arguments),
              },
            },
          )
          .toList(),
  };
  List<Map<String, dynamic>> _anthropicParts(AiTurn t) {
    if (t.role == 'tool') {
      return [
        {
          'type': 'tool_result',
          'tool_use_id': t.toolCallId,
          'content': t.text,
          'is_error': t.isError,
        },
      ];
    }
    if (t.providerParts.isNotEmpty) return t.providerParts;
    return [
      if (t.text.isNotEmpty) {'type': 'text', 'text': t.text},
      ...t.images.map(
        (i) => {
          'type': 'image',
          'source': {'type': 'base64', 'media_type': i.mime, 'data': i.base64},
        },
      ),
      ...t.calls.map(
        (c) => {
          'type': 'tool_use',
          'id': c.id,
          'name': c.name,
          'input': c.arguments,
        },
      ),
    ];
  }

  List<Map<String, dynamic>> _geminiParts(AiTurn t) {
    if (t.role == 'tool') {
      return [
        {
          'functionResponse': {
            'id': t.toolCallId,
            'name': t.toolName,
            'response': {t.isError ? 'error' : 'result': t.text},
          },
        },
      ];
    }
    if (t.providerParts.isNotEmpty) return t.providerParts;
    return [
      if (t.text.isNotEmpty) {'text': t.text},
      ...t.images.map(
        (i) => {
          'inlineData': {'mimeType': i.mime, 'data': i.base64},
        },
      ),
      ...t.calls.map(
        (c) => {
          ...c.providerState,
          'functionCall': {'id': c.id, 'name': c.name, 'args': c.arguments},
        },
      ),
    ];
  }

  Stream<StreamChunk> complete(
    AiConnection c,
    String key,
    String model,
    List<AiTurn> turns, {
    required CancelToken cancelToken,
    String system = '',
    List<AiTool> tools = const [],
    double temperature = .7,
    int? maxTokens,
    ReasoningLevel reasoningLevel = ReasoningLevel.auto,
    String? runId,
  }) async* {
    final watch = Stopwatch()..start();
    final fields = <String, Object?>{
      'request': newId(),
      'run': runId,
      'connection': c.id,
      'protocol': c.protocol.name,
      'model': model,
    };
    _logger.event(
      'client.request.started',
      channel: LogChannel.client,
      fields: fields,
    );
    int? status, firstOutputMs;
    var completed = false, inputTokens = 0, outputTokens = 0;
    Object? failure;
    try {
      await for (final event in _complete(
        c,
        key,
        model,
        turns,
        cancelToken: cancelToken,
        system: system,
        tools: tools,
        temperature: temperature,
        maxTokens: maxTokens,
        reasoningLevel: reasoningLevel,
        onStatus: (value) => status = value,
      )) {
        if (firstOutputMs == null &&
            (event is TextDelta ||
                event is ReasoningDelta ||
                event is ToolCallStart)) {
          firstOutputMs = watch.elapsedMilliseconds;
          _logger.event(
            'client.request.first_output',
            channel: LogChannel.client,
            fields: {...fields, 'elapsed_ms': firstOutputMs},
          );
        }
        if (event is Usage) {
          inputTokens = event.inputTokens;
          outputTokens = event.outputTokens;
        }
        yield event;
      }
      completed = true;
    } catch (error) {
      failure = error;
      rethrow;
    } finally {
      final cancelled =
          cancelToken.isCancelled ||
          (failure is DioException && CancelToken.isCancel(failure));
      _logger.event(
        'client.request.finished',
        channel: LogChannel.client,
        level: failure != null && !cancelled ? LogLevel.error : LogLevel.info,
        fields: {
          ...fields,
          'outcome': cancelled
              ? 'cancelled'
              : failure != null
              ? 'failed'
              : completed
              ? 'completed'
              : 'consumer_closed',
          'elapsed_ms': watch.elapsedMilliseconds,
          'first_output_ms': firstOutputMs,
          'input_tokens': inputTokens,
          'output_tokens': outputTokens,
          if (failure != null) ...AppLogger.errorFields(failure),
          if (status != null) 'http_status': status,
        },
      );
    }
  }

  Stream<StreamChunk> _complete(
    AiConnection c,
    String key,
    String model,
    List<AiTurn> turns, {
    required CancelToken cancelToken,
    String system = '',
    List<AiTool> tools = const [],
    double temperature = .7,
    int? maxTokens,
    ReasoningLevel reasoningLevel = ReasoningLevel.auto,
    required void Function(int?) onStatus,
  }) async* {
    c.validate();
    final path = switch (c.protocol) {
      AiProtocol.openai =>
        (c.apiPath?.trim().isNotEmpty ?? false)
            ? c.apiPath!.trim()
            : '/chat/completions',
      AiProtocol.anthropic => '/messages',
      AiProtocol.gemini =>
        '/models/${Uri.encodeComponent(model)}:streamGenerateContent?alt=sse',
    };
    final response = await dio.post<ResponseBody>(
      _base(c) + path,
      data: requestBody(
        c,
        model,
        turns,
        system: system,
        tools: tools,
        temperature: temperature,
        maxTokens: maxTokens,
        reasoningLevel: reasoningLevel,
      ),
      options: Options(
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
        headers: headers(c, key),
      ),
      cancelToken: cancelToken,
    );
    onStatus(response.statusCode);
    final body = response.data;
    if (body == null) throw StateError('Empty provider response');
    if (response.statusCode != 200) {
      final bytes = <int>[];
      await for (final part in body.stream) {
        bytes.addAll(part.take(8192 - bytes.length));
        if (bytes.length >= 8192) break;
      }
      throw StateError(
        LogRedactor.redact(
          'HTTP ${response.statusCode}: ${utf8.decode(bytes, allowMalformed: true)}',
        ),
      );
    }
    final decoder = ChatStreamDecoder(c.protocol);
    var doneMarker = false;
    await for (final event in decodeServerEvents(body.stream)) {
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      if (event.data == '[DONE]') {
        doneMarker = true;
        break;
      }
      final data = jsonDecode(event.data) as Map<String, dynamic>;
      if (data['error'] != null || data['type'] == 'error') {
        throw StateError(LogRedactor.redact(jsonEncode(data['error'] ?? data)));
      }
      for (final chunk in decoder.accept(data)) {
        yield chunk;
      }
    }
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    for (final chunk in decoder.finish(doneMarker: doneMarker)) {
      yield chunk;
    }
  }
}
