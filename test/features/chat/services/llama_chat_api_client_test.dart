import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_stream_delta.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

void main() {
  group('LlamaChatApiClient', () {
    late _TestRouterServer server;
    late LlamaChatApiClient client;

    setUp(() async {
      server = _TestRouterServer();
      await server.start();
      client = LlamaChatApiClient(
        settingsLoader: _FixedServerLaunchSettingsLoader(
          const ServerLaunchSettings(apiKey: 'secret'),
        ),
        modelLoadPollInterval: const Duration(milliseconds: 10),
        modelLoadTimeout: const Duration(milliseconds: 150),
      )..updateBaseUrl(server.baseUrl);
    });

    tearDown(() async {
      await server.close();
    });

    test('fetchModels maps model states', () async {
      server.models = <Map<String, Object?>>[
        _modelJson('alpha', 'loaded'),
        _modelJson('beta', 'unloaded'),
        _modelJson('gamma', 'failed'),
      ];

      final models = await client.fetchModels();

      expect(models, hasLength(3));
      expect(models.first.id, 'alpha');
      expect(models.first.status, ChatModelStatus.loaded);
      expect(models[1].status, ChatModelStatus.unloaded);
      expect(models[2].status, ChatModelStatus.failed);
      expect(server.lastAuthorization, 'Bearer secret');
    });

    test('loadModel polls until model becomes loaded', () async {
      server.models = <Map<String, Object?>>[
        _modelJson('alpha', 'loaded'),
        _modelJson('beta', 'unloaded'),
      ];
      server.loadBehavior = (String modelId) {
        server.models = <Map<String, Object?>>[
          _modelJson('alpha', 'loaded'),
          _modelJson('beta', 'loading'),
        ];
      };
      server.onModelsRequested = () {
        if (server.modelRequestCount >= 2) {
          server.models = <Map<String, Object?>>[
            _modelJson('alpha', 'loaded'),
            _modelJson('beta', 'loaded'),
          ];
        }
      };

      await client.loadModel('beta');

      expect(server.loadRequestCount, 1);
      expect(server.modelRequestCount, greaterThanOrEqualTo(2));
    });

    test('loadModel surfaces API errors', () async {
      server.models = <Map<String, Object?>>[_modelJson('beta', 'unloaded')];
      server.loadErrorMessage = 'cannot load beta';

      expect(
        () => client.loadModel('beta'),
        throwsA(
          isA<LlamaChatApiException>().having(
            (error) => error.message,
            'message',
            'cannot load beta',
          ),
        ),
      );
    });

    test('unloadModel polls until model becomes unloaded', () async {
      server.models = <Map<String, Object?>>[
        _modelJson('alpha', 'loaded'),
        _modelJson('beta', 'loaded'),
      ];
      server.unloadBehavior = (String modelId) {
        server.models = <Map<String, Object?>>[
          _modelJson('alpha', 'loaded'),
          _modelJson('beta', 'loading'),
        ];
      };
      server.onModelsRequested = () {
        if (server.modelRequestCount >= 2) {
          server.models = <Map<String, Object?>>[
            _modelJson('alpha', 'loaded'),
            _modelJson('beta', 'unloaded'),
          ];
        }
      };

      await client.unloadModel('beta');

      expect(server.unloadRequestCount, 1);
      expect(server.lastUnloadedModelId, 'beta');
      expect(server.modelRequestCount, greaterThanOrEqualTo(2));
    });

    test('unloadModel surfaces API errors', () async {
      server.unloadErrorMessage = 'cannot unload beta';

      expect(
        () => client.unloadModel('beta'),
        throwsA(
          isA<LlamaChatApiException>().having(
            (error) => error.message,
            'message',
            'cannot unload beta',
          ),
        ),
      );
    });

    test('streamChatCompletion parses content and reasoning SSE chunks', () async {
      server.chatResponder = (request) async {
        request.response.statusCode = 200;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.add(
          utf8.encode(
            'data: {"choices":[{"delta":{"reasoning_content":"先分析问题。"}}]}\n\n',
          ),
        );
        request.response.add(
          utf8.encode('data: {"choices":[{"delta":{"content":"你"}}]}\n\n'),
        );
        request.response.add(
          utf8.encode(
            'data: {"choices":[{"delta":{"content":"好","reasoning_content":"再组织答案。"}}]}\n\n',
          ),
        );
        request.response.add(utf8.encode('data: [DONE]\n\n'));
        await request.response.close();
      };

      final chunks = await client
          .streamChatCompletion(
            modelId: 'alpha',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'm1',
                role: ChatRole.user,
                content: 'hello',
                createdAt: DateTime(2026, 3, 25),
              ),
            ],
            cancelToken: CancelToken(),
          )
          .toList();

      expect(chunks, <ChatStreamDelta>[
        const ChatStreamDelta(reasoningContent: '先分析问题。'),
        const ChatStreamDelta(content: '你'),
        const ChatStreamDelta(content: '好', reasoningContent: '再组织答案。'),
      ]);
      expect(server.lastChatRequestBody?['model'], 'alpha');
      expect(server.lastChatRequestBody?['messages'], <Map<String, Object?>>[
        <String, Object?>{'role': 'user', 'content': 'hello'},
      ]);
    });

    test('streamChatCompletion surfaces JSON error responses', () async {
      server.chatResponder = (request) async {
        request.response.statusCode = 401;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{'message': 'Invalid API Key'},
          }),
        );
        await request.response.close();
      };

      expect(
        () => client
            .streamChatCompletion(
              modelId: 'alpha',
              messages: const <ChatMessageRecord>[],
              cancelToken: CancelToken(),
            )
            .toList(),
        throwsA(
          isA<LlamaChatApiException>().having(
            (error) => error.message,
            'message',
            'Invalid API Key',
          ),
        ),
      );
    });
  });
}

Map<String, Object?> _modelJson(String id, String status) {
  return <String, Object?>{
    'id': id,
    'status': <String, Object?>{'value': status},
  };
}

class _FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  _FixedServerLaunchSettingsLoader(this.settings);

  final ServerLaunchSettings settings;

  @override
  Future<ServerLaunchSettings> load() async => settings;
}

class _TestRouterServer {
  HttpServer? _server;

  int modelRequestCount = 0;
  int loadRequestCount = 0;
  int unloadRequestCount = 0;
  String? loadErrorMessage;
  String? unloadErrorMessage;
  String? lastAuthorization;
  String? lastUnloadedModelId;
  Map<String, Object?>? lastChatRequestBody;
  void Function()? onModelsRequested;
  void Function(String modelId)? loadBehavior;
  void Function(String modelId)? unloadBehavior;
  Future<void> Function(HttpRequest request)? chatResponder;
  List<Map<String, Object?>> models = <Map<String, Object?>>[];

  String get baseUrl => 'http://127.0.0.1:$port';
  int get port => _server!.port;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_server!.forEach(_handleRequest));
  }

  Future<void> close() async {
    await _server?.close(force: true);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    lastAuthorization = request.headers.value('authorization');

    if (request.method == 'GET' && request.uri.path == '/models') {
      modelRequestCount += 1;
      onModelsRequested?.call();
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{'data': models}));
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && request.uri.path == '/models/load') {
      loadRequestCount += 1;
      final body = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final modelId = decoded['model'] as String;
      if (loadErrorMessage != null) {
        request.response.statusCode = 400;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{'message': loadErrorMessage},
          }),
        );
        await request.response.close();
        return;
      }
      loadBehavior?.call(modelId);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{'success': true}));
      await request.response.close();
      return;
    }

    if (request.method == 'POST' && request.uri.path == '/models/unload') {
      unloadRequestCount += 1;
      final body = await utf8.decoder.bind(request).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      lastUnloadedModelId = decoded['model'] as String;
      if (unloadErrorMessage != null) {
        request.response.statusCode = 400;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{'message': unloadErrorMessage},
          }),
        );
        await request.response.close();
        return;
      }
      unloadBehavior?.call(lastUnloadedModelId!);
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(<String, Object?>{'success': true}));
      await request.response.close();
      return;
    }

    if (request.method == 'POST' &&
        request.uri.path == '/v1/chat/completions' &&
        chatResponder != null) {
      final body = await utf8.decoder.bind(request).join();
      lastChatRequestBody = jsonDecode(body) as Map<String, Object?>;
      await chatResponder!(request);
      return;
    }

    request.response.statusCode = 404;
    await request.response.close();
  }
}
