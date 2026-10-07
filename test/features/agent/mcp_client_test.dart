import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/services/mcp_client.dart';

void main() {
  for (final transport in McpTransport.values) {
    test(
      '${transport.name} initializes, discovers and calls a remote tool',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        HttpResponse? stream;
        var calls = 0;
        final auth = <String?>[];
        final custom = <String?>[];
        server.listen((r) async {
          auth.add(r.headers.value('authorization'));
          custom.add(r.headers.value('x-api-key'));
          if (r.method == 'DELETE') {
            r.response.statusCode = 204;
            await r.response.close();
            return;
          }
          if (r.method == 'GET') {
            if (transport == McpTransport.sse) {
              stream = r.response;
              stream!.bufferOutput = false;
              stream!.headers.contentType = ContentType('text', 'event-stream');
              stream!.write('event: endpoint\ndata: /messages\n\n');
              await stream!.flush();
            } else {
              r.response.statusCode = 405;
              await r.response.close();
            }
            return;
          }
          final msg = jsonDecode(await utf8.decodeStream(r)) as Map;
          if (!msg.containsKey('id')) {
            r.response.statusCode = 202;
            await r.response.close();
            return;
          }
          final result = switch (msg['method']) {
            'initialize' => {
              'protocolVersion': '2025-03-26',
              'capabilities': {'tools': {}},
              'serverInfo': {'name': 'test', 'version': '1'},
            },
            'tools/list' => {
              'tools': [
                {
                  'name': 'echo',
                  'description': 'echo',
                  'inputSchema': {
                    'type': 'object',
                    'properties': {
                      'text': {'type': 'string'},
                    },
                  },
                },
              ],
            },
            'tools/call' => {
              'content': [
                {'type': 'text', 'text': msg['params']['arguments']['text']},
              ],
            },
            _ => {},
          };
          if (msg['method'] == 'tools/call') calls++;
          final reply = jsonEncode({
            'jsonrpc': '2.0',
            'id': msg['id'],
            'result': result,
          });
          if (transport == McpTransport.sse) {
            r.response.statusCode = 202;
            await r.response.close();
            stream!.write('data: $reply\n\n');
            await stream!.flush();
          } else {
            r.response.headers.contentType = ContentType.json;
            r.response.headers.set('Mcp-Session-Id', 'test-session');
            r.response.write(reply);
            await r.response.close();
          }
        });
        final logger = AppLogger();
        addTearDown(logger.dispose);
        final client = McpClient(
          McpServer(
            id: 'id',
            name: 'test',
            url: 'http://127.0.0.1:${server.port}/mcp',
            transport: transport,
          ),
          'secret',
          headers: const {'X-API-Key': 'custom-header-fixture'},
          logger: logger,
          runId: 'test-run',
        );
        try {
          await client.connect();
          expect((await client.listTools()).single['name'], 'echo');
          final result = await client.callTool('echo', {
            'text': 'hello',
          }, CancelToken());
          expect(result['content'][0]['text'], 'hello');
          expect(calls, 1);
          expect(auth, everyElement('Bearer secret'));
          expect(custom, everyElement('custom-header-fixture'));
          final events = logger.entriesFor(LogChannel.agent);
          expect(
            events.where((e) => e.message.startsWith('agent.mcp.connected')),
            hasLength(1),
          );
          final called = events.singleWhere(
            (e) =>
                e.message.startsWith('agent.mcp.request_completed') &&
                e.message.contains('method="tools/call"'),
          );
          expect(called.message, contains('run="test-run"'));
          expect(called.message, contains('elapsed_ms='));
          final diagnostic = events.map((e) => e.message).join();
          for (final excluded in [
            'hello',
            'secret',
            'custom-header-fixture',
            'test-session',
            '/mcp',
            '/messages',
          ]) {
            expect(diagnostic, isNot(contains(excluded)));
          }
        } finally {
          await client.close();
          await server.close(force: true);
        }
      },
    );
  }
  test(
    'MCP credential validation rejects reserved, duplicate and injected headers',
    () {
      expect(McpCredentials.fromStored('legacy-token').token, 'legacy-token');
      expect(
        () => McpCredentials.parseHeaders('{"X-Key":42}'),
        throwsFormatException,
      );
      for (final headers in <Map<String, String>>[
        {'Content-Type': 'text/plain'},
        {'X-Key': 'one', 'x-key': 'two'},
        {'X-Key': 'value\r\nOther: injected'},
        {'Authorization': 'another token'},
      ]) {
        expect(
          () => McpCredentials(token: 'token', headers: headers).validate(),
          throwsFormatException,
        );
      }
    },
  );
}
