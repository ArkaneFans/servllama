import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/models/chat_stream_delta.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

void main() {
  group('ChatProvider', () {
    late _FakeChatSessionRepository repository;
    late _FakeLlamaChatApiClient apiClient;
    late ChatProvider provider;

    setUp(() {
      repository = _FakeChatSessionRepository();
      apiClient = _FakeLlamaChatApiClient();
      provider = ChatProvider(repository: repository, apiClient: apiClient);
      provider.updateServerState(
        baseUrl: 'http://127.0.0.1:8080',
        isServerRunning: true,
      );
    });

    test('load keeps startup state as a blank chat page', () async {
      repository.sessions = <ChatSessionRecord>[
        _session(id: 's1', title: '会话一'),
        _session(id: 's2', title: '会话二'),
      ];
      apiClient.models = <ChatModelOption>[
        const ChatModelOption(
          id: 'alpha',
          displayName: 'alpha',
          status: ChatModelStatus.loaded,
        ),
        const ChatModelOption(
          id: 'beta',
          displayName: 'beta',
          status: ChatModelStatus.unloaded,
        ),
      ];

      await provider.load();

      expect(provider.sessions, hasLength(2));
      expect(provider.selectedSession, isNull);
      expect(provider.isShowingDraftSession, isTrue);
      expect(provider.currentSessionTitle, ChatProvider.defaultSessionTitle);
      expect(provider.visibleMessages, isEmpty);
      expect(provider.currentModelId, isNull);
      expect(provider.modelSelectorLabel, '选择模型');
      expect(apiClient.fetchModelsCallCount, 0);
    });

    test(
      'switching sessions keeps current model unselected before user picks one',
      () async {
        repository.sessions = <ChatSessionRecord>[
          _session(id: 's1', title: '会话一'),
          _session(id: 's2', title: '会话二'),
        ];
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];

        await provider.load();
        provider.selectSession('s2');

        expect(provider.selectedSession?.id, 's2');
        expect(provider.currentModelId, isNull);
        expect(provider.modelSelectorLabel, '选择模型');
        expect(apiClient.fetchModelsCallCount, 0);
      },
    );

    test(
      'updateServerState does not auto-refresh models when server starts',
      () async {
        final repository = _FakeChatSessionRepository();
        final apiClient = _FakeLlamaChatApiClient();
        final provider = ChatProvider(
          repository: repository,
          apiClient: apiClient,
        );

        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];

        await provider.load();
        provider.updateServerState(
          baseUrl: 'http://127.0.0.1:8080',
          isServerRunning: true,
        );

        expect(provider.isServerRunning, isTrue);
        expect(provider.models, isEmpty);
        expect(apiClient.fetchModelsCallCount, 0);
      },
    );

    test(
      'loadAndSelectModel exposes loading state and selects loaded model',
      () async {
        repository.sessions = <ChatSessionRecord>[
          _session(id: 's1', title: '会话'),
        ];
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
          const ChatModelOption(
            id: 'beta',
            displayName: 'beta',
            status: ChatModelStatus.unloaded,
          ),
        ];
        apiClient.loadCompleter = Completer<void>();

        await provider.load();
        await provider.refreshModels();

        final future = provider.loadAndSelectModel('beta');

        expect(provider.loadingModelId, 'beta');

        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
          const ChatModelOption(
            id: 'beta',
            displayName: 'beta',
            status: ChatModelStatus.loaded,
          ),
        ];
        apiClient.loadCompleter!.complete();
        await future;

        expect(provider.loadingModelId, isNull);
        expect(provider.currentModelId, 'beta');
        expect(
          provider.loadedModels.map((model) => model.id),
          contains('beta'),
        );
        expect(provider.modelSelectorLabel, 'beta');
      },
    );

    test('unloadModel clears current selection when unloading current model', () async {
      apiClient.models = <ChatModelOption>[
        const ChatModelOption(
          id: 'alpha',
          displayName: 'alpha',
          status: ChatModelStatus.loaded,
        ),
        const ChatModelOption(
          id: 'beta',
          displayName: 'beta',
          status: ChatModelStatus.loaded,
        ),
      ];
      apiClient.unloadCompleter = Completer<void>();

      await provider.load();
      await provider.refreshModels();
      provider.selectLoadedModel('alpha');

      final future = provider.unloadModel('alpha');

      expect(provider.loadingModelId, 'alpha');

      apiClient.models = <ChatModelOption>[
        const ChatModelOption(
          id: 'alpha',
          displayName: 'alpha',
          status: ChatModelStatus.unloaded,
        ),
        const ChatModelOption(
          id: 'beta',
          displayName: 'beta',
          status: ChatModelStatus.loaded,
        ),
      ];
      apiClient.unloadCompleter!.complete();
      await future;

      expect(provider.loadingModelId, isNull);
      expect(provider.currentModelId, isNull);
      expect(provider.modelSelectorLabel, '选择模型');
      expect(
        provider.availableModels.map((model) => model.id),
        contains('alpha'),
      );
    });

    test('unloadModel keeps selection when unloading another loaded model', () async {
      apiClient.models = <ChatModelOption>[
        const ChatModelOption(
          id: 'alpha',
          displayName: 'alpha',
          status: ChatModelStatus.loaded,
        ),
        const ChatModelOption(
          id: 'beta',
          displayName: 'beta',
          status: ChatModelStatus.loaded,
        ),
      ];

      await provider.load();
      await provider.refreshModels();
      provider.selectLoadedModel('alpha');

      apiClient.models = <ChatModelOption>[
        const ChatModelOption(
          id: 'alpha',
          displayName: 'alpha',
          status: ChatModelStatus.loaded,
        ),
        const ChatModelOption(
          id: 'beta',
          displayName: 'beta',
          status: ChatModelStatus.unloaded,
        ),
      ];
      await provider.unloadModel('beta');

      expect(provider.currentModelId, 'alpha');
      expect(provider.modelSelectorLabel, 'alpha');
      expect(
        provider.availableModels.map((model) => model.id),
        contains('beta'),
      );
    });

    test(
      'sendMessage stores content and reasoning after selecting a loaded model',
      () async {
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];
        apiClient.streamDeltas = <ChatStreamDelta>[
          const ChatStreamDelta(reasoningContent: '先思考'),
          const ChatStreamDelta(content: '你'),
          const ChatStreamDelta(content: '好', reasoningContent: '再补充'),
        ];

        await provider.load();
        await provider.refreshModels();
        provider.selectLoadedModel('alpha');
        await provider.sendMessage('hello');

        expect(provider.sessions, hasLength(1));
        expect(repository.sessions, hasLength(1));
        expect(provider.selectedSession, isNotNull);
        final messages = provider.selectedSession!.messages;
        expect(messages, hasLength(2));
        expect(messages.first.modelName, 'alpha');
        expect(messages.last.modelName, 'alpha');
        expect(messages.last.content, '你好');
        expect(messages.last.reasoningContent, '先思考再补充');
      },
    );

    test(
      'sendMessage persists assistant message when only reasoning content is returned',
      () async {
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];
        apiClient.streamDeltas = <ChatStreamDelta>[
          const ChatStreamDelta(reasoningContent: '仅推理内容'),
        ];

        await provider.load();
        await provider.refreshModels();
        provider.selectLoadedModel('alpha');
        await provider.sendMessage('hello');

        expect(provider.sessions, hasLength(1));
        final messages = provider.selectedSession!.messages;
        expect(messages, hasLength(2));
        expect(messages.last.content, isEmpty);
        expect(messages.last.reasoningContent, '仅推理内容');
      },
    );

    test(
      'deleteSession works when repository returns a fixed-length list',
      () async {
        repository.returnFixedLengthList = true;
        repository.sessions = <ChatSessionRecord>[
          _session(id: 's1', title: '会话一'),
          _session(id: 's2', title: '会话二'),
        ];
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];

        await provider.load();
        await provider.deleteSession('s1');

        expect(provider.sessions.map((session) => session.id), <String>['s2']);
        expect(repository.sessions.map((session) => session.id), <String>[
          's2',
        ]);
        expect(provider.selectedSession, isNull);
      },
    );

    test(
      'deleteSession returns to blank startup state when deleting current session',
      () async {
        repository.sessions = <ChatSessionRecord>[
          _session(id: 's1', title: '会话一'),
          _session(id: 's2', title: '会话二'),
        ];
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];

        await provider.load();
        provider.selectSession('s2');
        await provider.deleteSession('s2');

        expect(provider.sessions.map((session) => session.id), <String>['s1']);
        expect(provider.selectedSession, isNull);
        expect(provider.currentSessionTitle, ChatProvider.defaultSessionTitle);
      },
    );

    test(
      'sendMessage is ignored when there is no loaded current model',
      () async {
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'beta',
            displayName: 'beta',
            status: ChatModelStatus.unloaded,
          ),
        ];

        await provider.load();
        await provider.sendMessage('hello');

        expect(provider.selectedSession, isNull);
        expect(provider.sessions, isEmpty);
        expect(repository.sessions, isEmpty);
      },
    );

    test('filteredSessions returns all sessions when query is empty', () async {
      repository.sessions = <ChatSessionRecord>[
        _session(id: 's1', title: 'Flutter 性能'),
        _session(id: 's2', title: '量子计算'),
      ];

      await provider.load();

      expect(provider.filteredSessions.map((session) => session.id), <String>[
        's1',
        's2',
      ]);
    });

    test(
      'filteredSessions uses case-insensitive fuzzy title matching',
      () async {
        repository.sessions = <ChatSessionRecord>[
          _session(id: 's1', title: 'Flutter 性能'),
          _session(id: 's2', title: '量子计算'),
          _session(id: 's3', title: 'flutter widget'),
        ];

        await provider.load();
        provider.updateSessionQuery('FLUT');

        expect(provider.filteredSessions.map((session) => session.id), <String>[
          's1',
          's3',
        ]);
      },
    );

    test('renaming a session updates current filtered results', () async {
      repository.sessions = <ChatSessionRecord>[
        _session(id: 's1', title: '旧会话'),
      ];

      await provider.load();
      provider.updateSessionQuery('新');

      expect(provider.filteredSessions, isEmpty);

      await provider.renameSession('s1', '新会话');

      expect(provider.filteredSessions.map((session) => session.id), <String>[
        's1',
      ]);
    });

    test('deleting a session updates current filtered results', () async {
      repository.sessions = <ChatSessionRecord>[
        _session(id: 's1', title: 'Flutter 性能'),
        _session(id: 's2', title: '量子计算'),
      ];

      await provider.load();
      provider.updateSessionQuery('Flutter');

      expect(provider.filteredSessions.map((session) => session.id), <String>[
        's1',
      ]);

      await provider.deleteSession('s1');

      expect(provider.filteredSessions, isEmpty);
    });
  });
}

class _FakeChatSessionRepository extends ChatSessionRepository {
  _FakeChatSessionRepository()
    : super(appSupportDirectory: Directory.systemTemp);

  List<ChatSessionRecord> sessions = <ChatSessionRecord>[];
  bool returnFixedLengthList = false;

  @override
  Future<List<ChatSessionRecord>> loadSessions() async {
    if (returnFixedLengthList) {
      return List<ChatSessionRecord>.from(sessions, growable: false);
    }
    return List<ChatSessionRecord>.from(sessions);
  }

  @override
  Future<void> saveSession(ChatSessionRecord session) async {
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      sessions[index] = session;
    } else {
      sessions.add(session);
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    sessions.removeWhere((session) => session.id == sessionId);
  }
}

class _FakeLlamaChatApiClient extends LlamaChatApiClient {
  _FakeLlamaChatApiClient()
    : super(settingsLoader: _FixedServerLaunchSettingsLoader());

  List<ChatModelOption> models = <ChatModelOption>[];
  Completer<void>? loadCompleter;
  Completer<void>? unloadCompleter;
  List<ChatStreamDelta> streamDeltas = const <ChatStreamDelta>[];
  String? lastBaseUrl;
  int fetchModelsCallCount = 0;

  @override
  void updateBaseUrl(String baseUrl) {
    lastBaseUrl = baseUrl;
  }

  @override
  Future<List<ChatModelOption>> fetchModels() async {
    fetchModelsCallCount += 1;
    return List<ChatModelOption>.from(models);
  }

  @override
  Future<void> loadModel(String modelId) async {
    if (loadCompleter != null) {
      await loadCompleter!.future;
    }
    models = models
        .map(
          (model) => model.id == modelId
              ? ChatModelOption(
                  id: model.id,
                  displayName: model.displayName,
                  status: ChatModelStatus.loaded,
                )
              : model,
        )
        .toList(growable: false);
  }

  @override
  Future<void> unloadModel(String modelId) async {
    if (unloadCompleter != null) {
      await unloadCompleter!.future;
    }
    models = models
        .map(
          (model) => model.id == modelId
              ? ChatModelOption(
                  id: model.id,
                  displayName: model.displayName,
                  status: ChatModelStatus.unloaded,
                )
              : model,
        )
        .toList(growable: false);
  }

  @override
  Stream<ChatStreamDelta> streamChatCompletion({
    required String modelId,
    required List<ChatMessageRecord> messages,
    required CancelToken cancelToken,
  }) {
    return Stream<ChatStreamDelta>.fromIterable(streamDeltas);
  }
}

class _FixedServerLaunchSettingsLoader extends ServerLaunchSettingsLoader {
  @override
  Future<ServerLaunchSettings> load() async => const ServerLaunchSettings();
}

ChatSessionRecord _session({
  required String id,
  required String title,
  List<ChatMessageRecord> messages = const <ChatMessageRecord>[],
}) {
  final timestamp = DateTime(2026, 3, 25, 10);
  return ChatSessionRecord(
    id: id,
    title: title,
    messages: messages,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
