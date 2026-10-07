import 'dart:convert';
import 'dart:io';

import 'package:servllama/features/agent/models/agent_records.dart';

/// A real HTTP MCP peer for approval and bounded-result integration tests.
class McpToolFixture {
  McpToolFixture._(this.server, this.result) {
    server.listen(_handle);
  }

  final HttpServer server;
  final Map<String, dynamic> result;
  int calls = 0;
  static const tool = {
    'name': 'echo',
    'description': 'Return the fixture result',
    'inputSchema': {
      'type': 'object',
      'properties': {
        'text': {'type': 'string'},
      },
      'required': ['text'],
      'additionalProperties': false,
    },
  };

  static Future<McpToolFixture> start(Map<String, dynamic> result) async =>
      McpToolFixture._(
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
        result,
      );

  McpServer get config => McpServer(
    id: '12345678-0000-0000-0000-000000000001',
    name: 'Fixture MCP',
    url: 'http://127.0.0.1:${server.port}/mcp',
    tools: const [tool],
  );

  Future<void> _handle(HttpRequest request) async {
    if (request.method != 'POST') {
      request.response.statusCode = request.method == 'DELETE' ? 204 : 405;
      await request.response.close();
      return;
    }
    final message = jsonDecode(await utf8.decodeStream(request)) as Map;
    if (!message.containsKey('id')) {
      request.response.statusCode = 202;
      await request.response.close();
      return;
    }
    if (message['method'] == 'tools/call') calls++;
    final response = switch (message['method']) {
      'initialize' => {
        'protocolVersion': '2025-03-26',
        'capabilities': {'tools': {}},
        'serverInfo': {'name': 'Fixture', 'version': '1'},
      },
      'tools/list' => {
        'tools': [tool],
      },
      'tools/call' => result,
      _ => <String, dynamic>{},
    };
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({'jsonrpc': '2.0', 'id': message['id'], 'result': response}),
    );
    await request.response.close();
  }

  Future<void> close() async {
    await server.close(force: true);
  }
}
