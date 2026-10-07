import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/security/secret_store.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';
import '../../support/mcp_tool_fixture.dart';

void main() {
  late AppDatabase db;
  late Directory dir;
  late AgentToolService service;
  late Assistant assistant;
  late CancelToken token;
  late ToolSession session;
  late AppLogger logger;
  setUp(() async {
    db = AppDatabase.memory();
    dir = await Directory.systemTemp.createTemp('v2-agent');
    logger = AppLogger();
    service = AgentToolService(AgentRepository(db), dir, logger: logger);
    assistant = const Assistant(
      id: 'a',
      name: 'test',
      tools: ['ask_user', 'clock'],
    );
    await AssistantRepository(db).saveAssistant(assistant);
    await AssistantRepository(db).saveConnection(
      const AiConnection(
        id: 'c',
        name: 'test',
        protocol: AiProtocol.openai,
        baseUrl: 'https://example.com/v1',
        models: ['m'],
      ),
    );
    token = CancelToken();
    session = await service.open(
      'run',
      'conversation',
      ChatRunConfig(
        assistant: assistant,
        connection: const AiConnection(
          id: 'c',
          name: 'test',
          protocol: AiProtocol.openai,
          baseUrl: 'https://example.com/v1',
          models: ['m'],
        ),
        key: '',
        modelId: 'm',
        isLocal: false,
      ),
      token,
    );
  });
  tearDown(() async {
    await session.close();
    service.dispose();
    logger.dispose();
    await db.close();
    await dir.delete(recursive: true);
  });
  Future<void> waitForApproval() async {
    for (var i = 0; i < 200; i++) {
      if (service.pendingCount > 0) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('approval was not reached');
  }

  Future<void> reopen() async {
    await session.close();
    await AssistantRepository(db).saveAssistant(assistant);
    session = await service.open(
      'next',
      'conversation',
      ChatRunConfig(
        assistant: assistant,
        connection: const AiConnection(
          id: 'c',
          name: 'test',
          protocol: AiProtocol.openai,
          baseUrl: 'https://example.com/v1',
          models: ['m'],
        ),
        key: '',
        modelId: 'm',
        isLocal: false,
      ),
      token,
    );
  }

  test(
    'retired file tools cannot be advertised or invoked by legacy grants',
    () async {
      const retired = ['list_files', 'read_file', 'write_file'];
      assistant = assistant.changed({
        'tools': ['clock', ...retired],
      });
      await reopen();
      expect(session.definitions.map((t) => t.name), ['clock']);
      for (final name in retired) {
        final result = await session.invoke(
          AiToolCall(id: name, name: name, arguments: const {}),
        );
        expect(result.isError, isTrue);
        expect(
          (await service.repository.invocation('next:$name'))!.state,
          'failed',
        );
      }
      expect(service.pendingCount, 0);
      expect(await db.query('SELECT * FROM artifacts'), isEmpty);
      expect(await Directory('${dir.path}/workspaces').exists(), isFalse);
    },
  );

  for (final failed in [false, true]) {
    test(
      'large MCP ${failed ? 'failure' : 'success'} keeps a bounded Unicode receipt without a workspace',
      () async {
        final fixture = await McpToolFixture.start({
          'isError': failed,
          'content': [
            {'type': 'text', 'text': '🙂中' * 10000},
          ],
        });
        addTearDown(fixture.close);
        final server = fixture.config;
        await service.repository.saveServer(server);
        final name = AgentToolService.mcpToolName(server.id, 'echo');
        assistant = assistant.changed({
          'tools': [name],
          'mcpServerIds': [server.id],
        });
        await reopen();
        final call = AiToolCall(
          id: 'large',
          name: name,
          arguments: const {'text': 'request'},
        );
        final running = session.invoke(call);
        await waitForApproval();
        await Future.wait([
          service.decide('next:large', true),
          service.decide('next:large', true),
        ]);
        final result = await running;
        expect(result.isError, failed);
        expect(utf8.encode(result.text).length, lessThanOrEqualTo(16 * 1024));
        expect(result.text, contains('[truncated:'));
        expect(result.text, isNot(contains('\uFFFD')));
        expect(result.text, isNot(contains('read_file')));
        final receipt = (await service.repository.invocation('next:large'))!;
        expect(receipt.state, failed ? 'failed' : 'succeeded');
        expect(receipt.payload['resultTruncated'], isTrue);
        expect(receipt.payload['result'], result.text);
        expect(receipt.payload.containsKey('artifactPath'), isFalse);
        if (failed) {
          await expectLater(session.invoke(call), throwsStateError);
        } else {
          expect((await session.invoke(call)).text, result.text);
        }
        expect(fixture.calls, 1);
        expect(await db.query('SELECT * FROM artifacts'), isEmpty);
        expect(await Directory('${dir.path}/workspaces').exists(), isFalse);
        await session.close();
      },
    );
  }

  test(
    'double approval and repeated call ID reuse only the saved answer',
    () async {
      const call = AiToolCall(
        id: 't',
        name: 'ask_user',
        arguments: {'question': 'private question'},
      );
      final running = session.invoke(call);
      await waitForApproval();
      await Future.wait([
        service.decide('run:t', true, answer: 'hello'),
        service.decide('run:t', true, answer: 'hello'),
      ]);
      expect((await running).isError, isFalse);
      await service.decide('run:t', true, answer: 'different');
      final repeated = await session.invoke(call);
      expect(jsonDecode(repeated.text), {'answer': 'hello'});
      expect(service.pendingCount, 0);
      expect(
        (await service.repository.history('conversation')).single.state,
        'succeeded',
      );
      final events = logger.entriesFor(LogChannel.agent);
      expect(
        events.where((e) => e.message.startsWith('agent.tool.decision')),
        hasLength(1),
      );
      expect(
        events.where((e) => e.message.contains('state="succeeded"')),
        hasLength(1),
      );
      final diagnostic = events.map((e) => e.message).join();
      for (final excluded in ['hello', 'private question', dir.path]) {
        expect(diagnostic, isNot(contains(excluded)));
      }
    },
  );
  test(
    'deleting the AI connection invalidates a pending tool approval',
    () async {
      final result = session.invoke(
        const AiToolCall(
          id: 'connection-deleted',
          name: 'ask_user',
          arguments: {'question': 'Never answer'},
        ),
      );
      final expectation = expectLater(result, throwsA(isA<DioException>()));
      await waitForApproval();
      await AssistantRepository(db).deleteConnection('c');
      await service.revalidate();
      await service.decide('run:connection-deleted', true);
      await expectation;
      expect(
        (await service.repository.invocation('run:connection-deleted'))!.state,
        'cancelled',
      );
    },
  );
  test(
    'MCP bearer and custom headers stay in secure storage and clear independently',
    () async {
      const draft = McpServer(
        id: '12345678-0000-0000-0000-000000000000',
        name: 'secure headers',
        url: 'https://example.com/mcp',
      );
      await service.saveMcp(
        draft,
        newKey: 'bearer-fixture',
        headers: {'X-API-Key': 'header-fixture'},
      );
      var saved = (await service.repository.servers()).single;
      var credentials = await service.credentialsFor(saved);
      expect(credentials.token, 'bearer-fixture');
      expect(credentials.headers, {'X-API-Key': 'header-fixture'});
      final config = (await db.query(
        'SELECT config FROM mcp_servers',
      )).single.read<String>('config');
      expect(config, isNot(contains('bearer-fixture')));
      expect(config, isNot(contains('header-fixture')));
      await service.saveMcp(saved);
      expect(
        (await service.credentialsFor(
          (await service.repository.servers()).single,
        )).headers,
        credentials.headers,
      );
      final firstRef = saved.secretRef!;
      await service.saveMcp(saved, clearKey: true);
      saved = (await service.repository.servers()).single;
      credentials = await service.credentialsFor(saved);
      expect(credentials.token, isEmpty);
      expect(credentials.headers['X-API-Key'], 'header-fixture');
      expect(await SecretStore.instance.read(firstRef), isNull);
      await service.saveMcp(saved, clearHeaders: true);
      expect((await service.repository.servers()).single.secretRef, isNull);
    },
  );
  test(
    'deleting a selected skill clears bindings and invalidates pending approval',
    () async {
      await session.close();
      final source = File('${dir.path}/SKILL.md');
      await source.writeAsString(
        '---\nname: guide\ndescription: guide\n---\nAsk for missing information.',
      );
      final skill = await service.skills.importPackage(source);
      assistant = assistant.changed({
        'skillIds': [skill.id],
      });
      await AssistantRepository(db).saveAssistant(assistant);
      session = await service.open(
        'selected',
        'conversation',
        ChatRunConfig(
          assistant: assistant,
          connection: const AiConnection(
            id: 'c',
            name: 'test',
            protocol: AiProtocol.openai,
            baseUrl: 'https://example.com/v1',
            models: ['m'],
          ),
          key: '',
          modelId: 'm',
          isLocal: false,
        ),
        token,
      );
      final running = session.invoke(
        const AiToolCall(
          id: 'ask',
          name: 'ask_user',
          arguments: {'question': 'Never answer'},
        ),
      );
      final expectation = expectLater(running, throwsA(isA<DioException>()));
      await waitForApproval();
      await service.deleteSkill(skill);
      await service.decide('selected:ask', true);
      await expectation;
      final saved = (await AssistantRepository(db).assistants()).single;
      expect(saved.skillIds, isEmpty);
      expect(saved.revision, assistant.revision + 1);
      expect(session.config.assistant.skillIds, [skill.id]);
      expect(
        (await service.repository.invocation('selected:ask'))!.state,
        'cancelled',
      );
      expect(await service.repository.skills(), isEmpty);
    },
  );
  test(
    'MCP deletion removes stale catalog grants but preserves other capabilities',
    () async {
      await session.close();
      const server = McpServer(
        id: '12345678-0000-0000-0000-000000000000',
        name: 'removed',
        url: 'https://example.com/mcp',
      );
      const other = '87654321-0000-0000-0000-000000000000';
      final keep = AgentToolService.mcpToolName(other, 'keep');
      assistant = assistant.changed({
        'mcpServerIds': [server.id, other],
        'tools': [
          'clock',
          AgentToolService.mcpToolName(server.id, 'old-catalog-tool'),
          keep,
        ],
      });
      await AssistantRepository(db).saveAssistant(assistant);
      await service.repository.saveServer(server);
      await service.deleteMcp(server);
      final saved = (await AssistantRepository(db).assistants()).single;
      expect(saved.mcpServerIds, [other]);
      expect(saved.tools, ['clock', keep]);
      expect(await service.repository.servers(), isEmpty);
    },
  );
  test(
    'dependency deletion rolls back its assistant changes on database failure',
    () async {
      final skill = SkillRecord(
        id: 'skill',
        name: 'skill',
        path: '${dir.path}/skills/skill',
        hash: 'hash',
        description: 'test',
      );
      await service.repository.saveSkill(skill);
      await AssistantRepository(db).saveAssistant(
        assistant.changed({
          'skillIds': [skill.id],
        }),
      );
      await db.execute(
        "CREATE TRIGGER reject_skill_delete BEFORE DELETE ON skills BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(service.deleteSkill(skill), throwsA(anything));
      expect((await service.repository.skills()).single.id, skill.id);
      expect((await AssistantRepository(db).assistants()).single.skillIds, [
        skill.id,
      ]);
    },
  );
  test(
    'selected static skills load on demand and also work without tool calling',
    () async {
      await session.close();
      final source = File('${dir.path}/SKILL.md');
      await source.writeAsString(
        '---\nname: guide\ndescription: selected guide\n---\nPRIVATE BODY 🙂',
      );
      final skill = await service.skills.importPackage(source);
      assistant = assistant.changed({
        'skillIds': [skill.id],
      });
      await AssistantRepository(db).saveAssistant(assistant);
      ChatRunConfig config(bool supportsTools) => ChatRunConfig(
        assistant: assistant,
        connection: AiConnection(
          id: 'c',
          name: 'test',
          protocol: AiProtocol.openai,
          baseUrl: 'https://example.com/v1',
          models: ['m'],
          modelCapabilities: {
            'm': ModelCapabilities(supportsTools: supportsTools),
          },
        ),
        key: '',
        modelId: 'm',
        isLocal: false,
      );
      session = await service.open(
        'skill-run',
        'conversation',
        config(true),
        CancelToken(),
      );
      expect(session.skillInstructions, contains('selected guide'));
      expect(session.skillInstructions, isNot(contains('PRIVATE BODY')));
      expect(session.definitions.any((t) => t.name == 'read_skill'), isTrue);
      final body = await session.invoke(
        AiToolCall(id: 'body', name: 'read_skill', arguments: {'id': skill.id}),
      );
      expect(body.isError, isFalse);
      expect(body.text, contains('PRIVATE BODY'));
      final offset = (jsonDecode(body.text)['text'] as String).indexOf('🙂');
      final read = await session.invoke(
        AiToolCall(
          id: 'unicode',
          name: 'read_skill',
          arguments: {'id': skill.id, 'offset': offset, 'limit': 1},
        ),
      );
      expect(jsonDecode(read.text)['text'], '🙂');
      final invalid = await session.invoke(
        AiToolCall(
          id: 'split',
          name: 'read_skill',
          arguments: {'id': skill.id, 'offset': offset + 1},
        ),
      );
      expect(invalid.isError, isTrue);
      final other = await session.invoke(
        const AiToolCall(
          id: 'other',
          name: 'read_skill',
          arguments: {'id': 'not-selected'},
        ),
      );
      expect(other.isError, isTrue);
      await session.close();
      session = await service.open(
        'no-tools',
        'conversation',
        config(false),
        CancelToken(),
      );
      expect(session.definitions, isEmpty);
      expect(session.skillInstructions, contains('PRIVATE BODY'));
    },
  );
  test('revocation cancels a pending user question', () async {
    final running = session.invoke(
      const AiToolCall(
        id: 't',
        name: 'ask_user',
        arguments: {'question': 'Never answer'},
      ),
    );
    final expectation = expectLater(running, throwsA(isA<DioException>()));
    await waitForApproval();
    await AssistantRepository(
      db,
    ).saveAssistant(assistant.changed({'tools': [], 'revision': 2}));
    await service.revalidate();
    await expectation;
    expect((await service.repository.invocation('run:t'))!.state, 'cancelled');
    expect(service.canDecide('run:t'), isFalse);
  });
  test(
    'restart classifies executing side effects as unknown and disables approval',
    () async {
      await service.repository.insert(
        const ToolInvocation(
          id: 'old:t',
          runId: 'old',
          callId: 't',
          conversationId: 'conversation',
          name: 'write_file',
          state: 'executing',
          payload: {},
        ),
      );
      await service.repository.recover();
      expect(
        (await service.repository.invocation('old:t'))!.state,
        'unknownOutcome',
      );
      await service.decide('old:t', true);
      expect(
        (await service.repository.invocation('old:t'))!.state,
        'unknownOutcome',
      );
    },
  );
}
