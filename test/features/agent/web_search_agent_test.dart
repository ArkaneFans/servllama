import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/agent/models/web_search.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/agent/services/web_search_service.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';

import 'web_search_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory dir;
  late AgentToolService service;
  late AssistantRepository assistants;
  late Dio dio;
  late AppLogger logger;
  late Assistant assistant;
  late ToolSession session;
  late CancelToken token;
  late int requests;
  Completer<void>? delayed, started;

  ChatRunConfig config({bool tools = true}) => ChatRunConfig(
    assistant: assistant,
    connection: AiConnection(
      id: 'local',
      name: 'local',
      protocol: AiProtocol.openai,
      baseUrl: 'http://127.0.0.1:9999/v1',
      models: ['model'],
      modelCapabilities: {'model': ModelCapabilities(supportsTools: tools)},
    ),
    key: '',
    modelId: 'model',
    isLocal: true,
  );
  Future<void> reopen(String id, {bool tools = true}) async {
    await session.close();
    token = CancelToken();
    session = await service.open(
      id,
      'conversation',
      config(tools: tools),
      token,
    );
  }

  setUp(() async {
    db = AppDatabase.memory();
    dir = await Directory.systemTemp.createTemp('web-search-agent');
    logger = AppLogger();
    requests = 0;
    delayed = null;
    started = null;
    dio = searchTestDio((request, cancelled) async {
      requests++;
      if (delayed != null) {
        started!.complete();
        await Future.any([delayed!.future, cancelled!]);
      }
      return searchHtml(bingSearchFixture);
    });
    service = AgentToolService(
      AgentRepository(db),
      dir,
      logger: logger,
      webSearch: WebSearchService(dio: dio, logger: logger),
    );
    assistants = AssistantRepository(db);
    assistant = const Assistant(
      id: 'assistant',
      name: 'Assistant',
      tools: ['web_search'],
      webSearch: WebSearchOptions(maxResults: 3),
    );
    await assistants.saveAssistant(assistant);
    token = CancelToken();
    session = await service.open('run', 'conversation', config(), token);
  });
  tearDown(() async {
    if (delayed != null && !delayed!.isCompleted) delayed!.complete();
    await session.close();
    service.dispose();
    dio.close();
    logger.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });

  const call = AiToolCall(
    id: 'search',
    name: 'web_search',
    arguments: {'query': 'documentation'},
  );

  test(
    'search uses an authorized run snapshot and durable receipt without approval',
    () async {
      expect(session.definitions.any((t) => t.name == 'web_search'), isTrue);
      final result = await session.invoke(call);
      expect(result.isError, isFalse);
      expect(service.pendingCount, 0);
      expect(
        (jsonDecode(result.text)['items'] as List).single['url'],
        'https://docs.example/guide',
      );
      final receipt = (await service.repository.history('conversation')).single;
      expect(receipt.state, 'succeeded');
      expect(receipt.payload['search'], {'provider': 'bing', 'maxResults': 3});
      expect(
        config().snapshot()['assistant']['webSearch'],
        receipt.payload['search'],
      );
      expect((await session.invoke(call)).text, result.text);
      expect(requests, 1);
    },
  );

  test(
    'search is never exposed without the assistant grant or provider tool support',
    () async {
      assistant = assistant.changed({'tools': <String>[]});
      await assistants.saveAssistant(assistant);
      await reopen('disabled');
      expect(session.definitions, isEmpty);
      expect((await session.invoke(call)).isError, isTrue);
      expect(requests, 0);
      assistant = assistant.changed({
        'tools': ['web_search'],
      });
      await assistants.saveAssistant(assistant);
      await reopen('unsupported', tools: false);
      expect(session.definitions, isEmpty);
      expect((await session.invoke(call)).isError, isTrue);
      expect(requests, 0);
    },
  );

  test(
    'changing providers revokes the pending search rather than switching its destination',
    () async {
      delayed = Completer<void>();
      started = Completer<void>();
      final expectation = expectLater(
        session.invoke(call),
        throwsA(isA<DioException>()),
      );
      await started!.future;
      await assistants.saveAssistant(
        assistant.changed({
          'webSearch': const WebSearchOptions(
            provider: WebSearchProvider.duckduckgo,
          ).toJson(),
        }),
      );
      await service.revalidate();
      await expectation;
      expect(token.isCancelled, isTrue);
      expect(requests, 1);
      final receipt = (await service.repository.history('conversation')).single;
      expect(receipt.state, 'cancelled');
      expect(receipt.payload['search']['provider'], 'bing');
    },
  );

  test(
    'legacy assistants keep search disabled; settings persist and limit edits apply next run',
    () async {
      final legacy = Assistant.fromJson({
        'id': 'legacy',
        'name': 'Old assistant',
      });
      expect(legacy.tools, isEmpty);
      expect(legacy.webSearch.provider, WebSearchProvider.bing);
      expect(legacy.webSearch.maxResults, 5);
      final updated = assistant.changed({
        'webSearch': const WebSearchOptions(maxResults: 8).toJson(),
      });
      await assistants.saveAssistant(updated);
      expect((await assistants.assistants()).single.webSearch.maxResults, 8);
      expect(config().authorizedBy(updated, null), isTrue);
      expect(config().assistant.webSearch.maxResults, 3);
      await expectLater(
        assistants.saveAssistant(
          Assistant(
            id: 'bad',
            name: 'Bad',
            webSearch: const WebSearchOptions(maxResults: 50),
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
