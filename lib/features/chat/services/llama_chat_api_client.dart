import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_stream_delta.dart';

class LlamaChatApiException implements Exception {
  const LlamaChatApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LlamaChatApiClient {
  LlamaChatApiClient({
    Dio? dio,
    ServerLaunchSettingsLoader? settingsLoader,
    Duration? modelLoadPollInterval,
    Duration? modelLoadTimeout,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(minutes: 2),
               sendTimeout: const Duration(seconds: 30),
               validateStatus: (_) => true,
             ),
           ),
       _settingsLoader = settingsLoader ?? ServerLaunchSettingsLoader(),
       _modelLoadPollInterval =
           modelLoadPollInterval ?? const Duration(milliseconds: 500),
       _modelLoadTimeout = modelLoadTimeout ?? const Duration(seconds: 30);

  final Dio _dio;
  final ServerLaunchSettingsLoader _settingsLoader;
  final Duration _modelLoadPollInterval;
  final Duration _modelLoadTimeout;

  String _baseUrl = 'http://127.0.0.1:8080';

  void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }

  Future<List<ChatModelOption>> fetchModels() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/models',
        options: Options(headers: await _headers()),
      );
      final body = response.data;
      if (response.statusCode != 200 || body == null) {
        throw await _exceptionFromResponse(
          statusCode: response.statusCode,
          body: body,
        );
      }

      final data = body['data'];
      if (data is! List) {
        throw const LlamaChatApiException('模型列表格式无效。');
      }

      final models = <ChatModelOption>[];
      for (final item in data) {
        if (item is! Map) {
          continue;
        }
        final normalized = Map<String, dynamic>.from(
          item.cast<Object?, Object?>(),
        );
        final id = '${normalized['id'] ?? ''}'.trim();
        if (id.isEmpty) {
          continue;
        }
        final statusValue =
            (normalized['status'] as Map?)?['value']?.toString() ?? '';
        models.add(
          ChatModelOption(
            id: id,
            displayName: id,
            status: _parseStatus(statusValue),
          ),
        );
      }

      models.sort(
        (left, right) => left.displayName.toLowerCase().compareTo(
          right.displayName.toLowerCase(),
        ),
      );
      return models;
    } on DioException catch (error) {
      throw _exceptionFromDio(error);
    }
  }

  Future<void> loadModel(String modelId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/models/load',
        data: <String, dynamic>{'model': modelId},
        options: Options(headers: await _headers()),
      );
      final body = response.data;
      if (response.statusCode != 200 ||
          body == null ||
          body['success'] != true) {
        throw await _exceptionFromResponse(
          statusCode: response.statusCode,
          body: body,
        );
      }

      final stopwatch = Stopwatch()..start();
      while (stopwatch.elapsed < _modelLoadTimeout) {
        final models = await fetchModels();
        for (final model in models) {
          if (model.id != modelId) {
            continue;
          }
          if (model.status == ChatModelStatus.loaded) {
            return;
          }
          if (model.status == ChatModelStatus.failed) {
            throw LlamaChatApiException('模型加载失败: ${model.displayName}');
          }
        }
        await Future<void>.delayed(_modelLoadPollInterval);
      }

      throw const LlamaChatApiException('模型加载超时，请稍后重试。');
    } on DioException catch (error) {
      throw _exceptionFromDio(error);
    }
  }

  Future<void> unloadModel(String modelId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/models/unload',
        data: <String, dynamic>{'model': modelId},
        options: Options(headers: await _headers()),
      );
      final body = response.data;
      if (response.statusCode != 200 ||
          body == null ||
          body['success'] != true) {
        throw await _exceptionFromResponse(
          statusCode: response.statusCode,
          body: body,
        );
      }

      final stopwatch = Stopwatch()..start();
      while (stopwatch.elapsed < _modelLoadTimeout) {
        final models = await fetchModels();
        for (final model in models) {
          if (model.id != modelId) {
            continue;
          }
          if (model.status == ChatModelStatus.unloaded) {
            return;
          }
        }
        await Future<void>.delayed(_modelLoadPollInterval);
      }

      throw const LlamaChatApiException('模型卸载超时，请稍后重试。');
    } on DioException catch (error) {
      throw _exceptionFromDio(error);
    }
  }

  Stream<ChatStreamDelta> streamChatCompletion({
    required String modelId,
    required List<ChatMessageRecord> messages,
    required CancelToken cancelToken,
  }) async* {
    Response<ResponseBody> response;
    try {
      response = await _dio.post<ResponseBody>(
        '$_baseUrl/v1/chat/completions',
        data: <String, dynamic>{
          'model': modelId,
          'stream': true,
          'messages': messages
              .map(
                (message) => <String, dynamic>{
                  'role': message.role.name,
                  'content': message.content,
                },
              )
              .toList(growable: false),
        },
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: await _headers(),
        ),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return;
      }
      throw _exceptionFromDio(error);
    }

    final body = response.data;
    if (response.statusCode != 200 || body == null) {
      throw await _exceptionFromResponse(
        statusCode: response.statusCode,
        body: body == null ? null : await _readResponseBody(body),
      );
    }

    var pending = '';
    try {
      await for (final chunk in body.stream) {
        pending += utf8.decode(chunk);
        final lines = pending.split('\n');
        pending = lines.removeLast();
        for (final line in lines) {
          final parsed = _parseSseLine(line);
          if (parsed == null) {
            continue;
          }
          if (parsed.isDone) {
            return;
          }
          final delta = parsed.delta;
          if (delta != null && !delta.isEmpty) {
            yield delta;
          }
        }
      }

      if (pending.trim().isNotEmpty) {
        final parsed = _parseSseLine(pending);
        if (parsed != null && !parsed.isDone) {
          final delta = parsed.delta;
          if (delta != null && !delta.isEmpty) {
            yield delta;
          }
        }
      }
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return;
      }
      throw _exceptionFromDio(error);
    }
  }

  ChatModelStatus _parseStatus(String statusValue) {
    switch (statusValue.trim().toLowerCase()) {
      case 'loaded':
        return ChatModelStatus.loaded;
      case 'loading':
        return ChatModelStatus.loading;
      case 'failed':
        return ChatModelStatus.failed;
      case 'unloaded':
      default:
        return ChatModelStatus.unloaded;
    }
  }

  _ParsedSseLine? _parseSseLine(String rawLine) {
    final line = rawLine.trim();
    if (!line.startsWith('data:')) {
      return null;
    }

    final payload = line.substring(5).trim();
    if (payload.isEmpty) {
      return null;
    }
    if (payload == '[DONE]') {
      return const _ParsedSseLine.done();
    }

    final decoded = jsonDecode(payload);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return null;
    }

    final choice = choices.first;
    if (choice is! Map) {
      return null;
    }

    final normalized = Map<String, dynamic>.from(
      choice.cast<Object?, Object?>(),
    );
    var content = '';
    var reasoningContent = '';

    final delta = normalized['delta'];
    if (delta is Map) {
      content = _coerceContent(delta['content']);
      reasoningContent = _coerceContent(delta['reasoning_content']);
    }

    if (content.isEmpty) {
      content = _coerceContent(normalized['text']);
    }

    final message = normalized['message'];
    if (message is Map) {
      if (content.isEmpty) {
        content = _coerceContent(message['content']);
      }
      if (reasoningContent.isEmpty) {
        reasoningContent = _coerceContent(message['reasoning_content']);
      }
    }

    if (content.isEmpty && reasoningContent.isEmpty) {
      return null;
    }

    return _ParsedSseLine.delta(
      ChatStreamDelta(content: content, reasoningContent: reasoningContent),
    );
  }

  String _coerceContent(Object? value) {
    if (value is String) {
      return value;
    }
    if (value is List) {
      final buffer = StringBuffer();
      for (final item in value) {
        if (item is String) {
          buffer.write(item);
        } else if (item is Map && item['text'] is String) {
          buffer.write(item['text'] as String);
        }
      }
      return buffer.toString();
    }
    return '';
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final settings = await _settingsLoader.load();
    if (settings.apiKey.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${settings.apiKey}';
    }
    return headers;
  }

  LlamaChatApiException _exceptionFromDio(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final message = _messageFromBody(responseData);
      if (message != null) {
        return LlamaChatApiException(message);
      }
    }
    final message = error.message?.trim();
    if (message != null && message.isNotEmpty) {
      return LlamaChatApiException(message);
    }
    return const LlamaChatApiException('请求失败，请稍后重试。');
  }

  Future<LlamaChatApiException> _exceptionFromResponse({
    required int? statusCode,
    required Object? body,
  }) async {
    if (body is String) {
      final decoded = _tryDecodeJson(body);
      final message = _messageFromBody(decoded);
      if (message != null) {
        return LlamaChatApiException(message);
      }
      if (body.trim().isNotEmpty) {
        return LlamaChatApiException(body.trim());
      }
    }
    if (body is Map<String, dynamic>) {
      final message = _messageFromBody(body);
      if (message != null) {
        return LlamaChatApiException(message);
      }
    }

    final codeText = statusCode == null ? '' : '($statusCode)';
    return LlamaChatApiException('请求失败$codeText');
  }

  Map<String, dynamic>? _tryDecodeJson(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  String? _messageFromBody(Map<String, dynamic>? body) {
    if (body == null) {
      return null;
    }
    final error = body['error'];
    if (error is Map && error['message'] is String) {
      return (error['message'] as String).trim();
    }
    if (body['message'] is String) {
      return (body['message'] as String).trim();
    }
    return null;
  }

  Future<String> _readResponseBody(ResponseBody body) async {
    final chunks = <int>[];
    await for (final chunk in body.stream) {
      chunks.addAll(chunk);
    }
    return utf8.decode(chunks);
  }
}

class _ParsedSseLine {
  const _ParsedSseLine.done() : isDone = true, delta = null;

  const _ParsedSseLine.delta(this.delta) : isDone = false;

  final bool isDone;
  final ChatStreamDelta? delta;
}
