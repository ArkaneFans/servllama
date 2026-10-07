import 'dart:convert';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/assistants/models/assistant.dart';

class AgentRepository {
  AgentRepository(this.db);
  final AppDatabase db;

  /// Called in the same transaction as dependency deletion. Historical Run
  /// snapshots remain intact, but cannot authorize another tool invocation.
  Future<void> removeAssistantBindings({
    String? skillId,
    String? serverId,
  }) async {
    final prefix = serverId == null ? null : McpServer.toolPrefix(serverId);
    for (final row in await db.query('SELECT config FROM assistants')) {
      final previous = Assistant.fromJson(
        jsonDecode(row.read<String>('config')),
      );
      final skills = previous.skillIds.where((id) => id != skillId).toList();
      final servers = previous.mcpServerIds
          .where((id) => id != serverId)
          .toList();
      final tools = previous.tools
          .where((name) => prefix == null || !name.startsWith(prefix))
          .toList();
      if (skills.length == previous.skillIds.length &&
          servers.length == previous.mcpServerIds.length &&
          tools.length == previous.tools.length) {
        continue;
      }
      final saved = previous.changed({
        'skillIds': skills,
        'mcpServerIds': servers,
        'tools': tools,
        'revision': previous.revision + 1,
      });
      await db.execute('UPDATE assistants SET revision=?,config=? WHERE id=?', [
        saved.revision,
        jsonEncode(saved.toJson()),
        saved.id,
      ]);
    }
  }

  Future<List<SkillRecord>> skills() async =>
      (await db.query('SELECT config FROM skills ORDER BY name'))
          .map(
            (r) => SkillRecord.fromJson(jsonDecode(r.read<String>('config'))),
          )
          .toList();
  Future<void> saveSkill(SkillRecord s) => db.execute(
    'INSERT INTO skills(id,name,hash,config) VALUES(?,?,?,?) '
    'ON CONFLICT(id) DO UPDATE SET name=excluded.name,hash=excluded.hash,config=excluded.config',
    [s.id, s.name, s.hash, jsonEncode(s.toJson())],
  );
  Future<List<McpServer>> servers() async =>
      (await db.query('SELECT config FROM mcp_servers ORDER BY name'))
          .map((r) => McpServer.fromJson(jsonDecode(r.read<String>('config'))))
          .toList();
  Future<void> saveServer(McpServer s) => db.execute(
    'INSERT INTO mcp_servers(id,name,revision,config) VALUES(?,?,?,?) '
    'ON CONFLICT(id) DO UPDATE SET name=excluded.name,revision=excluded.revision,config=excluded.config',
    [s.id, s.name, s.revision, jsonEncode(s.toJson())],
  );
  Future<ToolInvocation?> invocation(String id) async {
    final rows = await db.query('SELECT * FROM tool_invocations WHERE id=?', [
      id,
    ]);
    return rows.isEmpty ? null : ToolInvocation.fromRow(rows.single);
  }

  Future<List<ToolInvocation>> history(
    String conversationId,
  ) async => (await db.query(
    'SELECT * FROM tool_invocations WHERE conversation_id=? ORDER BY created_at DESC,rowid DESC',
    [conversationId],
  )).map(ToolInvocation.fromRow).toList();

  Future<List<ToolInvocation>> forRun(
    String conversationId,
    String runId,
  ) async => (await db.query(
    'SELECT * FROM tool_invocations WHERE conversation_id=? AND run_id=? '
    'ORDER BY created_at,rowid',
    [conversationId, runId],
  )).map(ToolInvocation.fromRow).toList(growable: false);

  Future<void> insert(ToolInvocation i) async {
    await db.execute(
      'INSERT INTO tool_invocations(id,run_id,call_id,conversation_id,name,state,payload,created_at) VALUES(?,?,?,?,?,?,?,?)',
      [
        i.id,
        i.runId,
        i.callId,
        i.conversationId,
        i.name,
        i.state,
        jsonEncode(i.payload),
        DateTime.now().millisecondsSinceEpoch,
      ],
    );
  }

  Future<bool> transition(
    String id,
    String from,
    String to,
    Map<String, dynamic> payload,
  ) async =>
      await db.execute(
        'UPDATE tool_invocations SET state=?,payload=? WHERE id=? AND state=?',
        [to, jsonEncode(payload), id, from],
      ) ==
      1;
  Future<void> recover() async {
    await db.execute(
      "UPDATE tool_invocations SET state='unknownOutcome' WHERE state='executing'",
    );
    await db.execute(
      "UPDATE tool_invocations SET state='cancelled' WHERE state IN ('pendingApproval','approved','prepared')",
    );
  }
}
