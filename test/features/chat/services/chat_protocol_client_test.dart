import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';

void main() {
  test(
    'assistant copy preserves settings and provider deletion clears both model selections',
    () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final repo = AssistantRepository(db);
      final c = AiConnection(
        id: 'c',
        name: 'Test',
        protocol: AiProtocol.openai,
        baseUrl: 'https://example.com/v1',
      );
      await repo.saveConnection(c);
      final a = Assistant(
        id: 'a',
        name: 'A',
        chatTarget: const ChatTarget.remote('c', 'model'),
        tools: const ['clock'],
      );
      await repo.saveAssistant(a);
      await repo.saveAssistant(
        a.changed({
          'id': 'b',
          'name': 'B',
          'tools': ['file_read'],
        }),
      );
      await repo.deleteConnection('c');
      final loaded = await repo.assistants();
      expect(loaded.first.tools, ['clock']);
      expect(loaded.last.tools, ['file_read']);
      expect(loaded.first.chatTarget, isNull);
      expect(loaded.last.chatTarget, isNull);
      expect(await repo.connections(), isEmpty);
    },
  );
  for (final protocol in AiProtocol.values) {
    for (final streaming in [false, true]) {
      test(
        '${protocol.name} cancels HTTP ${streaming ? 'during SSE' : 'before response headers'}',
        () async {
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          final connected = Completer<void>();
          final disconnected = Completer<void>();
          HttpHeaders? headers;
          server.listen((request) async {
            await request.drain<void>();
            headers = request.headers;
            final socket = await request.response.detachSocket(
              writeHeaders: false,
            );
            addTearDown(socket.destroy);
            socket.listen(
              (_) {},
              onDone: () {
                if (!disconnected.isCompleted) disconnected.complete();
              },
              onError: (Object _) {
                if (!disconnected.isCompleted) disconnected.complete();
              },
            );
            if (streaming) {
              socket.write(
                'HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nConnection: close\r\n\r\n: keep-alive\n\n',
              );
              await socket.flush();
            }
            connected.complete();
          });
          final logger = AppLogger();
          addTearDown(logger.dispose);
          final client = ChatProtocolClient(logger: logger);
          addTearDown(() => client.dio.close(force: true));
          final cancel = CancelToken();
          final result = expectLater(
            client.complete(
              AiConnection(
                id: 'c',
                name: 'HTTP',
                protocol: protocol,
                baseUrl: 'http://127.0.0.1:${server.port}/v1',
              ),
              '',
              'model',
              [const AiTurn(role: 'user', text: 'hello')],
              cancelToken: cancel,
            ).toList(),
            throwsA(
              isA<DioException>().having(
                (e) => e.type,
                'type',
                DioExceptionType.cancel,
              ),
            ),
          );
          await connected.future.timeout(const Duration(seconds: 5));
          cancel.cancel('user canceled');
          await result;
          await disconnected.future.timeout(const Duration(seconds: 5));
          expect(headers!.value('X-ServLlama-Request-Id'), isNull);
          final events = logger.entriesFor(LogChannel.client);
          expect(
            events.where((e) => e.message.startsWith('client.request.started')),
            hasLength(1),
          );
          final finished = events
              .where((e) => e.message.startsWith('client.request.finished'))
              .single;
          expect(finished.level, LogLevel.info);
          expect(finished.message, contains('outcome="cancelled"'));
          expect(events.map((e) => e.message).join(), isNot(contains('hello')));
        },
      );
    }
    test('${protocol.name} streams text and normalizes tool calls', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      Map? request;
      server.listen((r) async {
        request = jsonDecode(await utf8.decodeStream(r));
        r.response.headers.contentType = ContentType(
          'text',
          'event-stream',
          charset: 'utf-8',
        );
        final events = switch (protocol) {
          AiProtocol.openai => [
            {
              'choices': [
                {
                  'delta': {'content': '你好'},
                },
              ],
            },
            {
              'choices': [
                {
                  'delta': {
                    'tool_calls': [
                      {
                        'index': 0,
                        'id': 't1',
                        'function': {'name': 'clock', 'arguments': '{'},
                      },
                    ],
                  },
                },
              ],
            },
            {
              'choices': [
                {
                  'delta': {
                    'tool_calls': [
                      {
                        'index': 0,
                        'function': {'arguments': '}'},
                      },
                    ],
                  },
                  'finish_reason': 'tool_calls',
                },
              ],
              'usage': {'prompt_tokens': 12, 'completion_tokens': 8},
            },
          ],
          AiProtocol.anthropic => [
            {
              'type': 'content_block_start',
              'index': 0,
              'content_block': {'type': 'text', 'text': ''},
            },
            {
              'type': 'content_block_delta',
              'index': 0,
              'delta': {'type': 'text_delta', 'text': '你好'},
            },
            {
              'type': 'content_block_start',
              'index': 1,
              'content_block': {
                'type': 'tool_use',
                'id': 't1',
                'name': 'clock',
                'input': {},
              },
            },
            {
              'type': 'content_block_delta',
              'index': 1,
              'delta': {'type': 'input_json_delta', 'partial_json': '{}'},
            },
            {
              'type': 'message_delta',
              'delta': {'stop_reason': 'tool_use'},
              'usage': {'output_tokens': 8},
            },
          ],
          AiProtocol.gemini => [
            {
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': '你好'},
                      {
                        'functionCall': {
                          'id': 't1',
                          'name': 'clock',
                          'args': {},
                        },
                        'thoughtSignature': 'sig',
                      },
                    ],
                  },
                  'finishReason': 'STOP',
                },
              ],
              'usageMetadata': {
                'promptTokenCount': 12,
                'candidatesTokenCount': 8,
              },
            },
          ],
        };
        final data = events.map((e) => 'data: ${jsonEncode(e)}\n\n').join();
        // Deliberately split every UTF-8 sequence.
        for (final b in utf8.encode(data)) {
          r.response.add([b]);
        }
        await r.response.close();
      });
      final c = AiConnection(
        id: 'c',
        name: 'test',
        protocol: protocol,
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
      );
      final logger = AppLogger();
      addTearDown(logger.dispose);
      final client = ChatProtocolClient(logger: logger);
      final received = await client
          .complete(
            c,
            'private-provider-key',
            'model',
            [const AiTurn(role: 'user', text: 'time?')],
            system: 'instructions',
            tools: [
              const AiTool('clock', 'Time', {
                'type': 'object',
                'properties': {},
              }),
            ],
            cancelToken: CancelToken(),
            runId: 'test-run',
          )
          .toList();
      expect(received.map((e) => e.text).join(), '你好');
      expect(received.last.calls.single.name, 'clock');
      expect(received.last.calls.single.arguments, isEmpty);
      final continuation = client.requestBody(c, 'model', [
        AiTurn(
          role: 'assistant',
          text: '你好',
          calls: received.last.calls,
          providerParts: received.last.providerParts,
        ),
        const AiTurn(
          role: 'tool',
          text: '12:00',
          toolCallId: 't1',
          toolName: 'clock',
        ),
      ]);
      expect(jsonEncode(continuation), contains('12:00'));
      if (protocol == AiProtocol.gemini) {
        expect(jsonEncode(continuation), contains('sig'));
      }
      expect(request, isNotNull);
      final events = logger.entriesFor(LogChannel.client);
      expect(
        events.where(
          (e) => e.message.startsWith('client.request.first_output'),
        ),
        hasLength(1),
      );
      final finished = events.last;
      expect(finished.message, contains('outcome="completed"'));
      expect(finished.message, contains('http_status=200'));
      expect(finished.message, contains('elapsed_ms='));
      expect(finished.message, contains('run="test-run"'));
      final diagnostic = events.map((e) => e.message).join('\n');
      for (final excluded in [
        'time?',
        'instructions',
        '你好',
        'private-provider-key',
        c.baseUrl,
      ]) {
        expect(diagnostic, isNot(contains(excluded)));
      }
      client.dio.close(force: true);
    });
  }
  test(
    'HTTP failures log status and timing without request or response payloads',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = 429;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'error': {'message': 'private-error-body'},
          }),
        );
        await request.response.close();
      });
      final logger = AppLogger();
      addTearDown(logger.dispose);
      final client = ChatProtocolClient(logger: logger);
      addTearDown(() => client.dio.close(force: true));
      final connection = AiConnection(
        id: 'provider',
        name: 'Private provider',
        protocol: AiProtocol.openai,
        baseUrl: 'http://127.0.0.1:${server.port}/v1',
      );
      await expectLater(
        client.complete(connection, 'private-http-key', 'model', [
          const AiTurn(role: 'user', text: 'private-request-body'),
        ], cancelToken: CancelToken()).toList(),
        throwsA(anything),
      );
      final finished = logger.entriesFor(LogChannel.client).last;
      expect(finished.level, LogLevel.error);
      expect(finished.message, contains('http_status=429'));
      expect(finished.message, contains('outcome="failed"'));
      expect(finished.message, contains('error_type='));
      final diagnostic = logger
          .entriesFor(LogChannel.client)
          .map((e) => e.message)
          .join();
      for (final excluded in [
        'private-error-body',
        'private-request-body',
        'private-http-key',
        connection.baseUrl,
      ]) {
        expect(diagnostic, isNot(contains(excluded)));
      }
      await expectLater(
        client.listModels(connection, 'private-http-key'),
        throwsA(isA<DioException>()),
      );
      expect(
        logger.entriesFor(LogChannel.client).last.message,
        startsWith('client.models.failed'),
      );
      expect(
        logger.entriesFor(LogChannel.client).last.message,
        contains('http_status=429'),
      );
    },
  );

  test(
    'unmarked transport EOF fails instead of committing a complete reply',
    () async {
      final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => s.close(force: true));
      s.listen((r) async {
        await r.drain<void>();
        r.response.write(
          'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n',
        );
        await r.response.close();
      });
      final c = AiConnection(
        id: 'c',
        name: 'test',
        protocol: AiProtocol.openai,
        baseUrl: 'http://127.0.0.1:${s.port}',
      );
      await expectLater(
        ChatProtocolClient()
            .complete(c, '', 'm', [], cancelToken: CancelToken())
            .toList(),
        throwsStateError,
      );
    },
  );
}
