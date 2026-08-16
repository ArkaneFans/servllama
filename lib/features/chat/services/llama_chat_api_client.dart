import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_stream_delta.dart';
import 'package:servllama/features/chat/services/image_attachment_service.dart';

/// Runs on a background isolate via [compute]. Returns null when the file
/// no longer exists (deleted attachments are skipped silently).
Future<String?> _encodeImageDataUrl(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    return null;
  }
  final bytes = await file.readAsBytes();
  final mimeType = ImageAttachmentService.mimeTypeForPath(filePath);
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}

class LlamaChatApiException implements Exception {
  const LlamaChatApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LlamaChatApiClient {
  static const Duration defaultChatReceiveTimeout = Duration(minutes: 2);

  LlamaChatApiClient({
    Dio? dio,
    ServerLaunchSettingsLoader? settingsLoader,
    Duration? chatReceiveTimeout,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: chatReceiveTimeout ?? defaultChatReceiveTimeout,
               sendTimeout: const Duration(seconds: 30),
               validateStatus: (_) => true,
             ),
           ),
       _settingsLoader = settingsLoader ?? ServerLaunchSettingsLoader();

  final Dio _dio;
  final ServerLaunchSettingsLoader _settingsLoader;

  String _baseUrl = 'http://127.0.0.1:8080';

  @visibleForTesting
  Dio get dio => _dio;

  void updateBaseUrl(String baseUrl) {
    _baseUrl = baseUrl;
  }

  void updateReceiveTimeout(Duration timeout) {
    _dio.options.receiveTimeout = timeout;
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
          'messages': await _serializeMessages(messages),
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

    // A stateful decoder is required: multi-byte UTF-8 sequences can be
    // split across network chunks. LineSplitter also emits a trailing line
    // that lacks a final newline when the stream closes.
    final lines = body.stream
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());
    try {
      await for (final line in lines) {
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
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) {
        return;
      }
      throw _exceptionFromDio(error);
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

    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      // Tolerate malformed lines (server error text, truncated tail on a
      // dropped connection) instead of aborting the whole generation.
      return null;
    }
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

  Future<List<Map<String, dynamic>>> _serializeMessages(
    List<ChatMessageRecord> messages,
  ) async {
    final serialized = <Map<String, dynamic>>[];
    for (final message in messages) {
      final content = await _buildMessageContent(message);
      serialized.add({'role': message.role.name, 'content': content});
    }
    return serialized;
  }

  Future<dynamic> _buildMessageContent(ChatMessageRecord message) async {
    if (message.imageFilePaths.isEmpty) {
      return message.content;
    }

    final parts = <Map<String, dynamic>>[
      {'type': 'text', 'text': message.content},
    ];

    for (final filePath in message.imageFilePaths) {
      // Multi-MB reads and base64 encoding would jank the UI isolate —
      // every send re-serializes all images in the prompt history.
      final dataUrl = await compute(_encodeImageDataUrl, filePath);
      if (dataUrl == null) {
        continue;
      }
      parts.add({
        'type': 'image_url',
        'image_url': {'url': dataUrl},
      });
    }

    return parts;
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
    return const Utf8Decoder(allowMalformed: true).convert(chunks);
  }
}

class _ParsedSseLine {
  const _ParsedSseLine.done() : isDone = true, delta = null;

  const _ParsedSseLine.delta(this.delta) : isDone = false;

  final bool isDone;
  final ChatStreamDelta? delta;
}
