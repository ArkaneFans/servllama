import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
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
      'load warms message store and preloads initial message windows',
      () async {
        repository.sessions = <ChatSessionRecord>[
          _session(id: 's1', title: '会话一', messages: _messages(count: 4)),
          _session(id: 's2', title: '会话二', messages: _messages(count: 4)),
          _session(id: 's3', title: '会话三', messages: _messages(count: 4)),
          _session(id: 's4', title: '会话四', messages: _messages(count: 4)),
          _session(id: 's5', title: '会话五', messages: _messages(count: 4)),
          _session(id: 's6', title: '会话六', messages: _messages(count: 4)),
          _session(id: 's7', title: '会话七', messages: _messages(count: 4)),
          _session(id: 's8', title: '会话八', messages: _messages(count: 4)),
          _session(id: 's9', title: '会话九', messages: _messages(count: 4)),
        ];

        await provider.load();
        await _flushMicrotasks();

        expect(repository.warmUpMessageStoreCallCount, 1);
        expect(
          repository.initialMessagesLoadCounts.keys,
          containsAll(<String>['s1', 's2', 's3', 's4', 's5', 's6', 's7', 's8']),
        );
        expect(repository.initialMessagesLoadCounts, isNot(contains('s9')));
      },
    );

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
        await provider.selectSession('s2');

        expect(provider.selectedSession?.id, 's2');
        expect(provider.currentModelId, isNull);
        expect(provider.modelSelectorLabel, '选择模型');
        expect(apiClient.fetchModelsCallCount, 0);
      },
    );

    test(
      'selectSession loads recent window and older messages on demand',
      () async {
        repository.sessions = <ChatSessionRecord>[
          _session(id: 's1', title: '长会话', messages: _messages(count: 65)),
        ];

        await provider.load();
        await provider.selectSession('s1');

        expect(provider.visibleMessages, hasLength(30));
        expect(provider.visibleMessages.first.id, 'm35');
        expect(provider.visibleMessages.last.id, 'm64');
        expect(provider.hasOlderMessages, isTrue);

        await provider.loadOlderMessages();

        expect(provider.visibleMessages, hasLength(60));
        expect(provider.visibleMessages.first.id, 'm5');
        expect(provider.visibleMessages.last.id, 'm64');
        expect(provider.hasOlderMessages, isTrue);

        await provider.loadOlderMessages();

        expect(provider.visibleMessages, hasLength(65));
        expect(provider.visibleMessages.first.id, 'm0');
        expect(provider.hasOlderMessages, isFalse);
      },
    );

    test(
      'selectSession uses budgeted initial window for heavy conversations',
      () async {
        repository.sessions = <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '重内容会话',
            messages: _messages(count: 10, contentLength: 12000),
          ),
        ];

        await provider.load();
        await provider.selectSession('s1');

        expect(provider.visibleMessages, hasLength(2));
        expect(provider.visibleMessages.first.id, 'm8');
        expect(provider.visibleMessages.last.id, 'm9');
      },
    );

    test('selectSession reuses cached initial window', () async {
      repository.sessions = <ChatSessionRecord>[
        _session(id: 's1', title: '会话一', messages: _messages(count: 8)),
        _session(id: 's2', title: '会话二', messages: _messages(count: 8)),
      ];

      await provider.load();
      await _flushMicrotasks();
      final firstLoadCount = repository.initialMessagesLoadCounts['s1'] ?? 0;

      await provider.selectSession('s1');
      await provider.selectSession('s2');
      await provider.selectSession('s1');

      expect(repository.initialMessagesLoadCounts['s1'], firstLoadCount);
    });

    test(
      'staged switch selects target before committing loaded messages',
      () async {
        repository.sessions = <ChatSessionRecord>[
          _session(id: 's1', title: '会话一', messages: _messages(count: 2)),
          _session(id: 's2', title: '会话二'),
          _session(id: 's3', title: '会话三'),
          _session(id: 's4', title: '会话四'),
          _session(id: 's5', title: '会话五'),
          _session(id: 's6', title: '会话六'),
          _session(id: 's7', title: '会话七'),
          _session(id: 's8', title: '会话八'),
          _session(id: 's9', title: '会话九', messages: _messages(count: 3)),
        ];
        final s9Blocker = Completer<void>();
        repository.initialMessagesLoadBlockers['s9'] = s9Blocker;

        await provider.load();
        await provider.selectSession('s1');
        final previousMessages = provider.visibleMessages;
        final previousRevision = provider.visibleMessagesRevision;

        final switchFuture = provider.switchSession('s9', staged: true);
        await _flushMicrotasks();

        expect(provider.selectedSession?.id, 's9');
        expect(provider.isLoadingMessages, isTrue);
        expect(identical(provider.visibleMessages, previousMessages), isTrue);
        expect(provider.visibleMessagesRevision, previousRevision);

        s9Blocker.complete();
        await switchFuture;

        expect(provider.isLoadingMessages, isFalse);
        expect(
          provider.visibleMessages.map((message) => message.id).toList(),
          <String>['m0', 'm1', 'm2'],
        );
        expect(provider.visibleMessagesRevision, greaterThan(previousRevision));
      },
    );

    test(
      'selectSession reloads when cached session signature changes',
      () async {
        repository.sessions = <ChatSessionRecord>[
          _session(id: 's1', title: '会话一', messages: _messages(count: 8)),
          _session(id: 's2', title: '会话二', messages: _messages(count: 8)),
        ];

        await provider.load();
        await _flushMicrotasks();
        await provider.selectSession('s1');
        final firstLoadCount = repository.initialMessagesLoadCounts['s1'] ?? 0;

        await provider.selectSession('s2');
        await provider.renameSession('s1', '会话一重命名');
        await provider.selectSession('s1');

        expect(
          repository.initialMessagesLoadCounts['s1'],
          greaterThan(firstLoadCount),
        );
      },
    );

    test(
      'sendMessage uses full history even when only recent window is visible',
      () async {
        repository.sessions = <ChatSessionRecord>[
          _session(id: 's1', title: '长会话', messages: _messages(count: 35)),
        ];
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];

        await provider.load();
        await provider.refreshModels();
        provider.selectLoadedModel('alpha');
        await provider.selectSession('s1');
        await provider.sendMessage('next');

        expect(provider.visibleMessages, hasLength(31));
        expect(provider.visibleMessages.first.id, 'm5');
        expect(provider.visibleMessages.last.content, 'next');
        expect(apiClient.lastStreamMessages, hasLength(36));
        expect(apiClient.lastStreamMessages.first.id, 'm0');
        expect(apiClient.lastStreamMessages.last.content, 'next');
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

    test('updateChatTimeout forwards receive timeout to api client', () {
      provider.updateChatTimeout(const Duration(seconds: 300));

      expect(
        provider.apiClient.dio.options.receiveTimeout,
        const Duration(seconds: 300),
      );
    });

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

    test(
      'unloadModel clears current selection when unloading current model',
      () async {
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
      },
    );

    test(
      'unloadModel keeps selection when unloading another loaded model',
      () async {
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
      },
    );

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
        final messages = provider.visibleMessages;
        expect(messages, hasLength(2));
        expect(messages.first.modelName, 'alpha');
        expect(messages.last.modelName, 'alpha');
        expect(messages.last.content, '你好');
        expect(messages.last.reasoningContent, '先思考再补充');
        final assistantWrites = repository.savedSingleMessages
            .where((message) => message.role == ChatRole.assistant)
            .toList(growable: false);
        // Draft is written at stream start, once per delta, and once more
        // when the stream completes; sibling messages are never rewritten.
        expect(assistantWrites.map((message) => message.content), <String>[
          '',
          '',
          '你',
          '你好',
          '你好',
        ]);
        expect(
          assistantWrites.map((message) => message.reasoningContent),
          <String>['', '先思考', '先思考', '先思考再补充', '先思考再补充'],
        );
        expect(
          repository.savedSingleMessages
              .where((message) => message.role == ChatRole.user)
              .map((message) => message.content),
          <String>['hello'],
        );
      },
    );

    test(
      'sendMessage detaches streaming notifier entries when the stream ends',
      () async {
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];
        apiClient.streamDeltas = <ChatStreamDelta>[
          const ChatStreamDelta(content: '回答'),
        ];

        await provider.load();
        await provider.refreshModels();
        provider.selectLoadedModel('alpha');
        await provider.sendMessage('hello');

        final assistantMessage = provider.visibleMessages.last;
        expect(assistantMessage.content, '回答');
        expect(
          provider.streamingMessages.listenableFor(assistantMessage.id),
          isNull,
        );
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
        final messages = provider.visibleMessages;
        expect(messages, hasLength(2));
        expect(messages.last.content, isEmpty);
        expect(messages.last.reasoningContent, '仅推理内容');
      },
    );

    test(
      'sendMessage removes empty assistant draft when stream returns nothing',
      () async {
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];
        apiClient.streamDeltas = const <ChatStreamDelta>[];

        await provider.load();
        await provider.refreshModels();
        provider.selectLoadedModel('alpha');
        await provider.sendMessage('hello');

        final messages = provider.visibleMessages;
        expect(messages, hasLength(1));
        expect(messages.single.role, ChatRole.user);
        // Only the initial empty draft write happened before cleanup, and
        // the draft record is gone from storage afterwards.
        expect(
          repository.savedSingleMessages
              .where((message) => message.role == ChatRole.assistant)
              .map((message) => message.content),
          <String>[''],
        );
        expect(
          repository.messages.values.map((message) => message.role),
          everyElement(ChatRole.user),
        );
      },
    );

    test(
      'sendMessage resets sending state when persistence throws',
      () async {
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];

        await provider.load();
        await provider.refreshModels();
        provider.selectLoadedModel('alpha');
        repository.loadAllMessagesError = StateError('storage failure');

        await expectLater(
          provider.sendMessage('hello'),
          throwsA(isA<StateError>()),
        );

        expect(provider.isSending, isFalse);
        expect(provider.canSend, isTrue);
      },
    );

    test(
      'regenerate restores the original message when the stream returns nothing',
      () async {
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];
        repository.sessions = <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'u1',
                role: ChatRole.user,
                content: '你好',
                createdAt: DateTime(2026, 3, 25, 11, 0),
              ),
              ChatMessageRecord(
                id: 'a1',
                role: ChatRole.assistant,
                content: '原回答',
                createdAt: DateTime(2026, 3, 25, 11, 1),
                modelName: 'alpha',
              ),
            ],
          ),
        ];
        apiClient.streamDeltas = const <ChatStreamDelta>[];

        await provider.load();
        await provider.refreshModels();
        provider.selectLoadedModel('alpha');
        await provider.selectSession('s1');

        await provider.regenerateFromMessage('a1');

        // The empty draft dirtied the stored record during streaming setup;
        // the fallback path must restore the original content.
        expect(repository.messages['a1']?.content, '原回答');
        expect(provider.visibleMessages.last.content, '原回答');
        expect(provider.isSending, isFalse);
        expect(
          provider.streamingMessages.listenableFor('a1'),
          isNull,
        );
      },
    );

    test('editMessage updates only the target message content', () async {
      repository.sessions = <ChatSessionRecord>[
        _session(
          id: 's1',
          title: '会话',
          messages: <ChatMessageRecord>[
            ChatMessageRecord(
              id: 'u1',
              role: ChatRole.user,
              content: '原始用户消息',
              createdAt: DateTime(2026, 3, 25, 11, 0),
            ),
            ChatMessageRecord(
              id: 'a1',
              role: ChatRole.assistant,
              content: '原始助手消息',
              createdAt: DateTime(2026, 3, 25, 11, 1),
              modelName: 'alpha',
              reasoningContent: '保留推理',
            ),
          ],
        ),
      ];

      await provider.load();
      await provider.selectSession('s1');

      await provider.editMessage(messageId: 'u1', newContent: '修改后的用户消息');

      final messages = provider.visibleMessages;
      expect(messages, hasLength(2));
      expect(messages.first.content, '修改后的用户消息');
      expect(messages.last.content, '原始助手消息');
      expect(messages.last.reasoningContent, '保留推理');
      expect(repository.messagesForSession('s1').first.content, '修改后的用户消息');
    });

    test('deleteMessage removes only the target message', () async {
      repository.sessions = <ChatSessionRecord>[
        _session(
          id: 's1',
          title: '会话',
          messages: <ChatMessageRecord>[
            ChatMessageRecord(
              id: 'u1',
              role: ChatRole.user,
              content: '第一条',
              createdAt: DateTime(2026, 3, 25, 11, 0),
            ),
            ChatMessageRecord(
              id: 'a1',
              role: ChatRole.assistant,
              content: '第二条',
              createdAt: DateTime(2026, 3, 25, 11, 1),
            ),
            ChatMessageRecord(
              id: 'u2',
              role: ChatRole.user,
              content: '第三条',
              createdAt: DateTime(2026, 3, 25, 11, 2),
            ),
          ],
        ),
      ];

      await provider.load();
      await provider.selectSession('s1');

      await provider.deleteMessage('a1');

      expect(provider.visibleMessages.map((message) => message.id), <String>[
        'u1',
        'u2',
      ]);
      expect(
        repository.messagesForSession('s1').map((message) => message.id),
        <String>['u1', 'u2'],
      );
    });

    test(
      'deleteMessage removes image attachments for deleted user message',
      () async {
        final attachment = File(
          '${Directory.systemTemp.path}\\servllama_chat_provider_attachment.txt',
        );
        await attachment.writeAsString('temp');
        addTearDown(() async {
          if (await attachment.exists()) {
            await attachment.delete();
          }
        });

        repository.sessions = <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'u1',
                role: ChatRole.user,
                content: '图片消息',
                createdAt: DateTime(2026, 3, 25, 11, 0),
                imageFilePaths: <String>[attachment.path],
              ),
            ],
          ),
        ];

        await provider.load();
        await provider.selectSession('s1');

        await provider.deleteMessage('u1');

        expect(provider.visibleMessages, isEmpty);
        expect(await attachment.exists(), isFalse);
      },
    );

    test(
      'regenerateFromMessage keeps assistant replies as selectable versions',
      () async {
        apiClient.models = <ChatModelOption>[
          const ChatModelOption(
            id: 'alpha',
            displayName: 'alpha',
            status: ChatModelStatus.loaded,
          ),
        ];
        repository.sessions = <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'u1',
                role: ChatRole.user,
                content: '你好',
                createdAt: DateTime(2026, 3, 25, 11, 0),
              ),
              ChatMessageRecord(
                id: 'a1',
                role: ChatRole.assistant,
                content: '旧回答',
                createdAt: DateTime(2026, 3, 25, 11, 1),
                modelName: 'alpha',
              ),
              ChatMessageRecord(
                id: 'u2',
                role: ChatRole.user,
                content: '继续',
                createdAt: DateTime(2026, 3, 25, 11, 2),
              ),
              ChatMessageRecord(
                id: 'a2',
                role: ChatRole.assistant,
                content: '待替换回答',
                createdAt: DateTime(2026, 3, 25, 11, 3),
                modelName: 'alpha',
              ),
            ],
          ),
        ];
        apiClient.streamDeltas = const <ChatStreamDelta>[
          ChatStreamDelta(content: '新'),
          ChatStreamDelta(content: '回答'),
        ];

        await provider.load();
        await provider.refreshModels();
        provider.selectLoadedModel('alpha');
        await provider.selectSession('s1');

        await provider.regenerateFromMessage('a2');

        final messages = provider.visibleMessages;
        expect(messages.map((message) => message.id).toList(), hasLength(4));
        expect(messages[0].content, '你好');
        expect(messages[1].content, '旧回答');
        expect(messages[2].content, '继续');
        expect(messages[3].content, '新回答');
        expect(messages[3].id, 'a2');
        expect(messages[3].versionIds, hasLength(2));
        expect(messages[3].currentVersionIndex, 1);
        expect(
          repository.versions.values.map((version) => version.content),
          containsAll(<String>['待替换回答', '新回答']),
        );
        final versionSnapshots = repository.savedVersions
            .where((version) => version.messageId == 'a2')
            .map((version) => version.content)
            .toList(growable: false);
        // Original snapshot, streaming start, two deltas, and the final
        // full save in the completion path.
        expect(versionSnapshots, <String>['待替换回答', '', '新', '新回答', '新回答']);
        expect(
          apiClient.lastStreamMessages.map((message) => message.content),
          <String>['你好', '旧回答', '继续'],
        );
      },
    );

    test('selectMessageVersion switches visible assistant version', () async {
      apiClient.models = <ChatModelOption>[
        const ChatModelOption(
          id: 'alpha',
          displayName: 'alpha',
          status: ChatModelStatus.loaded,
        ),
      ];
      repository.sessions = <ChatSessionRecord>[
        _session(
          id: 's1',
          title: '会话',
          messages: <ChatMessageRecord>[
            ChatMessageRecord(
              id: 'u1',
              role: ChatRole.user,
              content: '你好',
              createdAt: DateTime(2026, 3, 25, 11, 0),
            ),
            ChatMessageRecord(
              id: 'a1',
              role: ChatRole.assistant,
              content: '旧回答',
              createdAt: DateTime(2026, 3, 25, 11, 1),
              modelName: 'alpha',
            ),
          ],
        ),
      ];
      apiClient.streamDeltas = const <ChatStreamDelta>[
        ChatStreamDelta(content: '新回答'),
      ];

      await provider.load();
      await provider.refreshModels();
      provider.selectLoadedModel('alpha');
      await provider.selectSession('s1');
      await provider.regenerateFromMessage('a1');

      expect(provider.visibleMessages.last.content, '新回答');

      await provider.selectMessageVersion(messageId: 'a1', versionIndex: 0);

      expect(provider.visibleMessages.last.content, '旧回答');
      expect(provider.visibleMessages.last.currentVersionIndex, 0);

      await provider.selectMessageVersion(messageId: 'a1', versionIndex: 1);

      expect(provider.visibleMessages.last.content, '新回答');
      expect(provider.visibleMessages.last.currentVersionIndex, 1);
    });

    test(
      'canRegenerateMessage requires loaded model and nearest user message',
      () async {
        repository.sessions = <ChatSessionRecord>[
          _session(
            id: 's1',
            title: '会话',
            messages: <ChatMessageRecord>[
              ChatMessageRecord(
                id: 'a1',
                role: ChatRole.assistant,
                content: '孤立助手消息',
                createdAt: DateTime(2026, 3, 25, 11, 0),
              ),
            ],
          ),
        ];

        await provider.load();
        await provider.selectSession('s1');

        expect(provider.canRegenerateMessage('a1'), isFalse);
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
        await provider.selectSession('s2');
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
  final Map<String, ChatMessageRecord> messages = <String, ChatMessageRecord>{};
  final Map<String, ChatMessageVersionRecord> versions =
      <String, ChatMessageVersionRecord>{};
  final List<ChatSessionRecord> savedSessions = <ChatSessionRecord>[];
  final List<ChatMessageRecord> savedSingleMessages = <ChatMessageRecord>[];
  final List<ChatMessageVersionRecord> savedVersions =
      <ChatMessageVersionRecord>[];
  final Map<String, int> initialMessagesLoadCounts = <String, int>{};
  final Map<String, Completer<void>> initialMessagesLoadBlockers =
      <String, Completer<void>>{};
  int warmUpMessageStoreCallCount = 0;
  bool returnFixedLengthList = false;
  Object? loadAllMessagesError;

  @override
  Future<List<ChatSessionRecord>> loadSessions() async {
    final loadedSessions = sessions
        .map(_migrateSession)
        .toList(growable: !returnFixedLengthList);
    sessions = List<ChatSessionRecord>.from(loadedSessions);
    return loadedSessions;
  }

  @override
  Future<void> saveSession(ChatSessionRecord session) async {
    final cleanSession = _migrateSession(session);
    savedSessions.add(cleanSession);
    final index = sessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      sessions[index] = cleanSession;
    } else {
      sessions.add(cleanSession);
    }
  }

  @override
  Future<void> warmUpMessageStore() async {
    warmUpMessageStoreCallCount += 1;
  }

  @override
  Future<void> saveMessage(ChatMessageRecord message) async {
    messages[message.id] = message;
    savedSingleMessages.add(message);
  }

  @override
  Future<ChatMessageRecord?> loadMessage(String messageId) async {
    return messages[messageId];
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    ChatSessionRecord? session;
    for (final item in sessions) {
      if (item.id == sessionId) {
        session = item;
        break;
      }
    }
    if (session != null) {
      for (final messageId in session.messageIds) {
        messages.remove(messageId);
      }
    }
    sessions.removeWhere((session) => session.id == sessionId);
  }

  @override
  Future<List<ChatMessageRecord>> loadRecentMessages(
    ChatSessionRecord session, {
    int limit = 30,
  }) async {
    final start = session.messageIds.length > limit
        ? session.messageIds.length - limit
        : 0;
    return _messagesByIds(session.messageIds.skip(start));
  }

  @override
  Future<List<ChatMessageRecord>> loadInitialMessages(
    ChatSessionRecord session, {
    int minMessages = ChatSessionRepository.defaultInitialMessageMin,
    int maxMessages = ChatSessionRepository.defaultInitialMessageMax,
    int textBudget = ChatSessionRepository.defaultInitialTextBudget,
  }) async {
    initialMessagesLoadCounts[session.id] =
        (initialMessagesLoadCounts[session.id] ?? 0) + 1;
    final blocker = initialMessagesLoadBlockers[session.id];
    if (blocker != null) {
      await blocker.future;
    }
    final ids = session.messageIds;
    if (ids.isEmpty) {
      return const <ChatMessageRecord>[];
    }

    final minCount = minMessages.clamp(1, ids.length).toInt();
    final configuredMax = maxMessages <= 0
        ? ChatSessionRepository.defaultInitialMessageMax
        : maxMessages;
    final maxCount = configuredMax.clamp(minCount, ids.length).toInt();
    final budget = textBudget <= 0
        ? ChatSessionRepository.defaultInitialTextBudget
        : textBudget;
    final loadedMessages = <ChatMessageRecord>[];

    var index = ids.length;
    var weight = 0;
    while (index > 0 && loadedMessages.length < maxCount) {
      index -= 1;
      final message = messages[ids[index]];
      if (message == null) {
        continue;
      }
      loadedMessages.add(message);
      weight += _estimateInitialLoadWeight(message);
      if (loadedMessages.length >= minCount && weight >= budget) {
        break;
      }
    }

    if (loadedMessages.length.isOdd &&
        index > 0 &&
        loadedMessages.length < maxCount) {
      index -= 1;
      final message = messages[ids[index]];
      if (message != null) {
        loadedMessages.add(message);
      }
    }

    return loadedMessages.reversed.toList(growable: false);
  }

  @override
  Future<List<ChatMessageRecord>> loadMessagesBefore(
    ChatSessionRecord session, {
    required String beforeMessageId,
    int limit = 30,
  }) async {
    final beforeIndex = session.messageIds.indexOf(beforeMessageId);
    if (beforeIndex <= 0) {
      return const <ChatMessageRecord>[];
    }
    final start = beforeIndex > limit ? beforeIndex - limit : 0;
    return _messagesByIds(session.messageIds.sublist(start, beforeIndex));
  }

  @override
  Future<List<ChatMessageRecord>> loadAllMessages(
    ChatSessionRecord session,
  ) async {
    if (loadAllMessagesError != null) {
      throw loadAllMessagesError!;
    }
    return _messagesByIds(session.messageIds);
  }

  @override
  Future<void> deleteMessages(
    Iterable<ChatMessageRecord> deletedMessages,
  ) async {
    final messageList = deletedMessages.toList(growable: false);
    await deleteMessageResources(messageList);
    for (final message in messageList) {
      messages.remove(message.id);
    }
  }

  @override
  Future<void> saveMessageVersion(ChatMessageVersionRecord version) async {
    savedVersions.add(version);
    versions[version.id] = version;
  }

  @override
  Future<ChatMessageVersionRecord?> loadMessageVersion(String versionId) async {
    return versions[versionId];
  }

  @override
  Future<List<ChatMessageVersionRecord>> loadMessageVersions(
    Iterable<String> versionIds,
  ) async {
    return versionIds
        .map((versionId) => versions[versionId])
        .whereType<ChatMessageVersionRecord>()
        .toList(growable: false);
  }

  @override
  Future<void> deleteMessageVersions(Iterable<String> versionIds) async {
    for (final versionId in versionIds) {
      versions.remove(versionId);
    }
  }

  @override
  Future<void> deleteMessageResources(
    Iterable<ChatMessageRecord> messages,
  ) async {
    final messageList = messages.toList(growable: false);
    await deleteAttachmentFiles(
      messageList.expand((message) => message.imageFilePaths),
    );
    await deleteMessageVersions(
      messageList.expand((message) => message.versionIds),
    );
  }

  ChatSessionRecord _migrateSession(ChatSessionRecord session) {
    if (session.legacyMessages.isEmpty) {
      return session;
    }
    final savedMessages = session.legacyMessages
        .map((message) => message.copyWith(sessionId: session.id))
        .toList(growable: false);
    for (final message in savedMessages) {
      messages[message.id] = message;
    }
    return session.copyWith(
      messageIds: savedMessages
          .map((message) => message.id)
          .toList(growable: false),
      legacyMessages: const <ChatMessageRecord>[],
    );
  }

  List<ChatMessageRecord> _messagesByIds(Iterable<String> messageIds) {
    return messageIds
        .map((messageId) => messages[messageId])
        .whereType<ChatMessageRecord>()
        .toList(growable: false);
  }

  int _estimateInitialLoadWeight(ChatMessageRecord message) {
    final reasoningLength = message.reasoningContent?.length ?? 0;
    final textWeight = message.content.length + (reasoningLength * 0.8).round();
    final roleWeight = message.role == ChatRole.user && textWeight < 200
        ? 200
        : textWeight;
    return roleWeight + message.imageFilePaths.length * 1200;
  }

  List<ChatMessageRecord> messagesForSession(String sessionId) {
    final session = sessions.firstWhere((session) => session.id == sessionId);
    return _messagesByIds(session.messageIds);
  }
}

class _FakeLlamaChatApiClient extends LlamaChatApiClient {
  _FakeLlamaChatApiClient()
    : super(settingsLoader: _FixedServerLaunchSettingsLoader());

  List<ChatModelOption> models = <ChatModelOption>[];
  Completer<void>? loadCompleter;
  Completer<void>? unloadCompleter;
  List<ChatStreamDelta> streamDeltas = const <ChatStreamDelta>[];
  List<ChatMessageRecord> lastStreamMessages = const <ChatMessageRecord>[];
  String? lastBaseUrl;
  Duration? lastReceiveTimeout;
  int fetchModelsCallCount = 0;

  @override
  void updateBaseUrl(String baseUrl) {
    lastBaseUrl = baseUrl;
  }

  @override
  void updateReceiveTimeout(Duration timeout) {
    lastReceiveTimeout = timeout;
    super.updateReceiveTimeout(timeout);
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
    lastStreamMessages = List<ChatMessageRecord>.from(messages);
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

List<ChatMessageRecord> _messages({required int count, int? contentLength}) {
  return List<ChatMessageRecord>.generate(
    count,
    (index) => ChatMessageRecord(
      id: 'm$index',
      role: index.isEven ? ChatRole.user : ChatRole.assistant,
      content: contentLength == null
          ? 'message $index'
          : List<String>.filled(contentLength, 'x').join(),
      createdAt: DateTime(2026, 3, 25, 10, index),
    ),
  );
}

Future<void> _flushMicrotasks([int count = 8]) async {
  for (var index = 0; index < count; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
