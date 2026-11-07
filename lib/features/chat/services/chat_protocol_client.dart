import 'package:servllama/features/chat/models/generation_metrics.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/core/network/server_sent_events.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';

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
          'generationConfig': {
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

  Stream<AiEvent> complete(
    AiConnection c,
    String key,
    String model,
    List<AiTurn> turns, {
    required CancelToken cancelToken,
    String system = '',
    List<AiTool> tools = const [],
    double temperature = .7,
    int? maxTokens,
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
    int? status, firstOutputMs, firstOutputUs;
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
        onStatus: (value) => status = value,
      )) {
        if (firstOutputMs == null &&
            (event.text.isNotEmpty ||
                event.reasoning.isNotEmpty ||
                event.calls.isNotEmpty)) {
          firstOutputMs = watch.elapsedMilliseconds;
          _logger.event(
            'client.request.first_output',
            channel: LogChannel.client,
            fields: {...fields, 'elapsed_ms': firstOutputMs},
          );
        }
        if (event.isStreamingOutput) {
          firstOutputUs ??= watch.elapsedMicroseconds;
        }
        if (event.stopReason != null) {
          inputTokens = event.inputTokens;
          outputTokens = event.outputTokens;
        }
        if (event.stopReason != null && event.generationMetrics != null) {
          final first = firstOutputUs;
          yield AiEvent(
            text: event.text,
            reasoning: event.reasoning,
            calls: event.calls,
            providerParts: event.providerParts,
            inputTokens: event.inputTokens,
            outputTokens: event.outputTokens,
            stopReason: event.stopReason,
            generationMetrics: event.generationMetrics!.withEstimates(
              firstTokenMilliseconds: first == null ? null : first / 1000,
              outputMilliseconds: first == null
                  ? null
                  : (watch.elapsedMicroseconds - first) / 1000,
            ),
          );
        } else {
          yield event;
        }
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

  Stream<AiEvent> _complete(
    AiConnection c,
    String key,
    String model,
    List<AiTurn> turns, {
    required CancelToken cancelToken,
    String system = '',
    List<AiTool> tools = const [],
    double temperature = .7,
    int? maxTokens,
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
    final calls = <int, _CallBuffer>{};
    final parts = <int, Map<String, dynamic>>{};
    int? input, output, cachedInput;
    String? finish;
    GenerationMetrics? metrics;
    final isJson =
        response.headers
            .value('content-type')
            ?.toLowerCase()
            .contains('application/json') ??
        false;
    final events = isJson && c.protocol == AiProtocol.openai
        ? Stream<ServerEvent>.fromFuture(
            utf8.decoder
                .bind(body.stream)
                .join()
                .then((text) => ServerEvent(text)),
          )
        : decodeServerEvents(body.stream);
    await for (final event in events) {
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      if (event.data == '[DONE]') {
        finish ??= 'stop';
        break;
      }
      final data = jsonDecode(event.data) as Map<String, dynamic>;
      if (data['error'] != null || data['type'] == 'error') {
        throw StateError(LogRedactor.redact(jsonEncode(data['error'] ?? data)));
      }
      switch (c.protocol) {
        case AiProtocol.openai:
          if (data.containsKey('timings')) {
            metrics = GenerationMetrics.fromTimings(data['timings']);
          }
          final usage = data['usage'] as Map?;
          input =
              GenerationMetrics.tokenCount(usage?['prompt_tokens']) ?? input;
          output =
              GenerationMetrics.tokenCount(usage?['completion_tokens']) ??
              output;
          final details = usage?['prompt_tokens_details'];
          cachedInput =
              GenerationMetrics.tokenCount(
                details is Map ? details['cached_tokens'] : null,
              ) ??
              cachedInput;
          for (final choice
              in (data['choices'] as List? ?? []).whereType<Map>().take(1)) {
            finish = choice['finish_reason'] as String? ?? finish;
            final delta =
                choice['delta'] as Map? ?? choice['message'] as Map? ?? {};
            final text = delta['content'] as String? ?? '';
            final reasoning = delta['reasoning_content'] as String? ?? '';
            if (text.isNotEmpty || reasoning.isNotEmpty) {
              yield AiEvent(
                text: text,
                reasoning: reasoning,
                isStreamingOutput: !isJson,
              );
            }
            if (!isJson && (delta['tool_calls'] as List? ?? []).isNotEmpty) {
              yield const AiEvent(isStreamingOutput: true);
            }
            for (final tool
                in (delta['tool_calls'] as List? ?? []).whereType<Map>()) {
              final i = tool['index'] as int? ?? (isJson ? calls.length : 0);
              final b = calls.putIfAbsent(i, () => _CallBuffer());
              b.id = tool['id'] as String? ?? b.id;
              final fn = tool['function'] as Map? ?? {};
              b.name += (fn['name'] as String? ?? '');
              b.append(fn['arguments'] as String? ?? '');
            }
          }
        case AiProtocol.anthropic:
          final index = data['index'] as int? ?? 0;
          switch (data['type']) {
            case 'message_start':
              final usage = data['message']?['usage'] as Map?;
              final fresh = GenerationMetrics.tokenCount(
                usage?['input_tokens'],
              );
              final read = GenerationMetrics.tokenCount(
                usage?['cache_read_input_tokens'],
              );
              final created = GenerationMetrics.tokenCount(
                usage?['cache_creation_input_tokens'],
              );
              input = fresh == null
                  ? input
                  : fresh + (read ?? 0) + (created ?? 0);
              cachedInput = read;
            case 'content_block_start':
              final block = Map<String, dynamic>.from(
                data['content_block'] as Map,
              );
              parts[index] = block;
              if (block['type'] == 'tool_use') {
                if ((block['name'] as String? ?? '').isNotEmpty) {
                  yield const AiEvent(isStreamingOutput: true);
                }
                calls[index] = _CallBuffer()
                  ..id = block['id']
                  ..name = block['name'];
                if ((block['input'] as Map? ?? {}).isNotEmpty) {
                  calls[index]!.append(jsonEncode(block['input']));
                }
              }
              if (block['type'] == 'text' &&
                  (block['text'] as String? ?? '').isNotEmpty) {
                yield AiEvent(text: block['text'], isStreamingOutput: true);
              }
            case 'content_block_delta':
              final delta = data['delta'] as Map;
              final block = parts[index];
              switch (delta['type']) {
                case 'text_delta':
                  final t = delta['text'] as String;
                  block?['text'] = (block['text'] ?? '').toString() + t;
                  yield AiEvent(text: t, isStreamingOutput: t.isNotEmpty);
                case 'thinking_delta':
                  final t = delta['thinking'] as String;
                  block?['thinking'] = (block['thinking'] ?? '').toString() + t;
                  yield AiEvent(reasoning: t, isStreamingOutput: t.isNotEmpty);
                case 'signature_delta':
                  block?['signature'] =
                      (block['signature'] ?? '').toString() +
                      delta['signature'].toString();
                case 'input_json_delta':
                  if ((delta['partial_json'] as String? ?? '').isNotEmpty) {
                    yield const AiEvent(isStreamingOutput: true);
                  }
                  calls[index]?.append(delta['partial_json'] as String? ?? '');
              }
            case 'message_delta':
              finish = data['delta']?['stop_reason'] as String? ?? finish;
              output = data['usage']?['output_tokens'] as int? ?? output;
            case 'message_stop':
              finish ??= 'end_turn';
          }
        case AiProtocol.gemini:
          input = data['usageMetadata']?['promptTokenCount'] as int? ?? input;
          cachedInput =
              GenerationMetrics.tokenCount(
                data['usageMetadata']?['cachedContentTokenCount'],
              ) ??
              cachedInput;
          final candidates = GenerationMetrics.tokenCount(
            data['usageMetadata']?['candidatesTokenCount'],
          );
          final thoughts = GenerationMetrics.tokenCount(
            data['usageMetadata']?['thoughtsTokenCount'],
          );
          output = candidates == null ? output : candidates + (thoughts ?? 0);
          for (final candidate
              in (data['candidates'] as List? ?? []).whereType<Map>().take(1)) {
            finish = candidate['finishReason'] as String? ?? finish;
            for (final raw
                in (candidate['content']?['parts'] as List? ?? [])
                    .whereType<Map>()) {
              final part = Map<String, dynamic>.from(raw);
              parts[parts.length] = part;
              if (part['text'] is String) {
                yield part['thought'] == true
                    ? AiEvent(
                        reasoning: part['text'],
                        isStreamingOutput: (part['text'] as String).isNotEmpty,
                      )
                    : AiEvent(
                        text: part['text'],
                        isStreamingOutput: (part['text'] as String).isNotEmpty,
                      );
              }
              final fn = part['functionCall'] as Map?;
              if (fn != null) {
                yield const AiEvent(isStreamingOutput: true);
                calls[calls.length] = _CallBuffer()
                  ..id = (fn['id'] ?? 'gemini_${calls.length}') as String
                  ..name = fn['name'] as String
                  ..append(jsonEncode(fn['args'] ?? {}));
              }
            }
          }
          if (data['promptFeedback']?['blockReason'] != null) {
            throw StateError('Provider blocked the prompt');
          }
      }
      if (calls.length > 32 || parts.length > 2048) {
        throw const FormatException('Provider response limit exceeded');
      }
    }
    if (cancelToken.isCancelled) throw cancelToken.cancelError!;
    if (finish == null) {
      throw StateError('Provider stream interrupted before completion');
    }
    final completed = <AiToolCall>[];
    for (final entry in calls.entries) {
      final call = entry.value.finish();
      completed.add(call);
      if (c.protocol == AiProtocol.anthropic) {
        parts[entry.key]?['input'] = call.arguments;
      }
    }
    yield AiEvent(
      calls: completed,
      providerParts: parts.values.toList(),
      inputTokens: input ?? 0,
      outputTokens: output ?? 0,
      stopReason: finish,
      generationMetrics:
          const {
            'stop',
            'length',
            'tool_calls',
            'end_turn',
            'max_tokens',
            'tool_use',
            'STOP',
            'MAX_TOKENS',
          }.contains(finish)
          ? (metrics ?? const GenerationMetrics()).withUsage(
              inputTokens: input,
              outputTokens: output,
              cachedInputTokens: cachedInput,
            )
          : null,
    );
  }
}

class _CallBuffer {
  String id = '', name = '', json = '';
  void append(String value) {
    json += value;
    if (json.length > 128 * 1024) {
      throw const FormatException('Tool arguments exceed limit');
    }
  }

  AiToolCall finish() {
    final args = jsonDecode(json.isEmpty ? '{}' : json);
    if (id.isEmpty || name.isEmpty || args is! Map<String, dynamic>) {
      throw const FormatException('Invalid tool call');
    }
    return AiToolCall(id: id, name: name, arguments: args);
  }
}
