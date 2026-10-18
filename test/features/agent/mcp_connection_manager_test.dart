import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/models/mcp_connection.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';

import '../../support/mcp_tool_fixture.dart';

void main() {
  late AppDatabase db;
  late Directory directory;
  late AppLogger logger;
  late AgentToolService service;

  setUp(() async {
    db = AppDatabase.memory();
    directory = await Directory.systemTemp.createTemp('mcp-manager-');
    logger = AppLogger();
    service = AgentToolService(AgentRepository(db), directory, logger: logger);
  });

  tearDown(() async {
    service.dispose();
    logger.dispose();
    await db.close();
    await directory.delete(recursive: true);
  });

  Future<void> waitForStatus(String id, McpConnectionStatus expected) async {
    for (var i = 0; i < 400; i++) {
      if (service.mcp.stateFor(id).status == expected) return;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    fail('MCP server did not reach ${expected.name}');
  }

  test(
    'app-level sessions connect once and refresh their tool catalog',
    () async {
      final fixture = await McpToolFixture.start({
        'content': [
          {'type': 'text', 'text': 'ok'},
        ],
      });
      addTearDown(fixture.close);
      final server = fixture.config;
      await service.repository.saveServer(server);

      await service.mcp.start();
      await waitForStatus(server.id, McpConnectionStatus.connected);

      expect(service.mcp.stateFor(server.id).toolCount, 1);
      expect(fixture.initializes, 1);
      final connection = await service.mcp.ensureConnected(
        server,
        refreshTools: true,
      );
      expect(connection.tools.single['name'], 'echo');
      expect(fixture.initializes, 1);
      expect(fixture.toolListCalls, 2);

      await service.mcp.refreshAll();
      expect(
        service.mcp.stateFor(server.id).status,
        McpConnectionStatus.connected,
      );
      expect(fixture.initializes, 1);
      expect(fixture.toolListCalls, 3);
    },
  );

  test('failed app-level connections retain a user-visible error', () async {
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    final server = McpServer(
      id: '12345678-0000-0000-0000-000000000002',
      name: 'Unavailable MCP',
      url: 'http://127.0.0.1:$port/mcp',
    );
    await service.repository.saveServer(server);

    await service.mcp.refreshAll();

    final state = service.mcp.stateFor(server.id);
    expect(state.status, McpConnectionStatus.failed);
    expect(state.error, isNotEmpty);
  });

  test('disabled servers stay offline until enabled again', () async {
    final fixture = await McpToolFixture.start({
      'content': [
        {'type': 'text', 'text': 'ok'},
      ],
    });
    addTearDown(fixture.close);
    final base = fixture.config;
    final disabled = McpServer(
      id: base.id,
      name: base.name,
      url: base.url,
      enabled: false,
      tools: base.tools,
    );
    await service.repository.saveServer(disabled);

    await service.mcp.start();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(fixture.initializes, 0);
    expect(
      service.mcp.stateFor(disabled.id).status,
      McpConnectionStatus.disconnected,
    );
    await expectLater(service.mcp.ensureConnected(disabled), throwsStateError);

    final enabled = McpServer(
      id: base.id,
      name: base.name,
      url: base.url,
      tools: base.tools,
    );
    service.mcp.upsert(enabled);
    await waitForStatus(enabled.id, McpConnectionStatus.connected);
    expect(fixture.initializes, 1);

    service.mcp.upsert(disabled);
    expect(
      service.mcp.stateFor(disabled.id).status,
      McpConnectionStatus.disconnected,
    );
    await service.mcp.refreshAll();
    expect(
      service.mcp.stateFor(disabled.id).status,
      McpConnectionStatus.disconnected,
    );
    expect(fixture.initializes, 1);
  });
}
