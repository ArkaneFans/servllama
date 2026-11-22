import 'dart:convert';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/chat/models/message_part.dart';
import 'package:servllama/core/security/log_redactor.dart';
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
  Future<List<McpServer>> servers() async {
    final servers =
        (await db.query('SELECT config FROM mcp_servers ORDER BY name'))
            .map(
              (r) => McpServer.fromJson(jsonDecode(r.read<String>('config'))),
            )
            .toList();
    for (final server in servers) {
      for (final value in server.headers.values) {
        LogRedactor.remember(value);
      }
    }
    return servers;
  }

  Future<void> saveServer(McpServer s) => db.execute(
    'INSERT INTO mcp_servers(id,name,revision,config) VALUES(?,?,?,?) '
    'ON CONFLICT(id) DO UPDATE SET name=excluded.name,revision=excluded.revision,config=excluded.config',
    [s.id, s.name, s.revision, jsonEncode(s.toJson())],
  );
  Future<List<ToolActivity>> _toolParts(String where, List<Object> args) async {
    final rows = await db.query(
      'SELECT r.id,r.run_id,m.conversation_id,p.value AS part FROM message_revisions r '
      'JOIN messages m ON m.id=r.message_id JOIN json_each(r.parts) p '
      "ON json_extract(p.value,'\$.kind')='tool' WHERE r.run_id IS NOT NULL AND $where "
      'ORDER BY m.position,r.position,CAST(p.key AS INTEGER)',
      args,
    );
    return [
      for (final r in rows)
        ToolActivity(
          runId: r.read<String>('run_id'),
          conversationId: r.read<String>('conversation_id'),
          revisionId: r.read<String>('id'),
          part: ToolPart.fromJson(
            Map<String, dynamic>.from(jsonDecode(r.read<String>('part'))),
          ),
        ),
    ];
  }

  Future<ToolActivity?> toolActivity(String id) async => (await _toolParts(
    "r.run_id || ':' || COALESCE(json_extract(p.value,'\$.callId'),"
    "json_extract(p.value,'\$.id'))=?",
    [id],
  )).firstOrNull;

  Future<List<ToolActivity>> history(String conversationId) async {
    // Shared Run references yield copies of the same history, not new attempts.
    final parts = await _toolParts('m.conversation_id=?', [conversationId]);
    final unique = <String, ToolActivity>{};
    for (final p in parts) {
      unique[p.id] = p;
    }
    return unique.values.toList().reversed.toList();
  }

  Future<List<ToolActivity>> forRun(String conversationId, String runId) async {
    final parts = await _toolParts('m.conversation_id=? AND r.run_id=?', [
      conversationId,
      runId,
    ]);
    final unique = <String, ToolActivity>{};
    for (final p in parts) {
      unique[p.id] = p;
    }
    return List.unmodifiable(unique.values);
  }

  /// Reserve the validated call in the Run's owning draft before any effect.
  /// Existing streamed input keeps its ordinal and stable part ID.
  Future<void> prepare(
    String runId,
    String conversationId,
    String callId,
    String name,
    Map<String, dynamic> payload,
  ) => db.transaction(() async {
    final rows = await db.query(
      'SELECT r.id,r.parts FROM message_revisions r JOIN messages m ON m.id=r.message_id '
      'JOIN generation_runs g ON g.id=r.run_id WHERE r.run_id=? AND m.conversation_id=? '
      "AND r.is_draft=1 AND g.state='running' AND r.id=json_extract(g.snapshot,'\$.versionId')",
      [runId, conversationId],
    );
    if (rows.length != 1) {
      throw StateError('Tool requires its owning draft revision');
    }
    final row = rows.single;
    final parts = MessagePart.decode(row.read<String>('parts')).toList();
    final index = parts.indexWhere((p) => p is ToolPart && p.callId == callId);
    final part = index < 0
        ? ToolPart(
            id: 'call:$callId',
            callId: callId,
            name: name,
            input: jsonEncode(payload['arguments']),
            inputComplete: true,
          )
        : parts[index] as ToolPart;
    if (!part.inputIsMutable ||
        !part.inputComplete ||
        part.name != name ||
        (part.arguments != null &&
            jsonEncode(part.arguments) != jsonEncode(payload['arguments']))) {
      throw StateError('Tool call is incomplete or already attempted');
    }
    final prepared = part.withExecution('prepared', payload);
    if (index < 0) {
      parts.add(prepared);
    } else {
      parts[index] = prepared;
    }
    await db.execute('UPDATE message_revisions SET parts=? WHERE id=?', [
      MessagePart.encode(parts),
      row.read<String>('id'),
    ]);
  });

  /// Compare-and-set in the owning draft, preserving concurrent text writes.
  Future<bool> transition(
    String id,
    String from,
    String to,
    Map<String, dynamic> payload,
  ) => db.transaction(() async {
    final activity = await toolActivity(id);
    if (activity == null || activity.state != from) return false;
    final rows = await db.query(
      'SELECT parts FROM message_revisions WHERE id=? AND is_draft=1',
      [activity.revisionId],
    );
    if (rows.isEmpty) return false;
    final parts = MessagePart.decode(
      rows.single.read<String>('parts'),
    ).toList();
    final index = parts.indexWhere((p) => p.id == activity.part.id);
    if (index < 0 || (parts[index] as ToolPart).state.name != from) {
      return false;
    }
    parts[index] = (parts[index] as ToolPart).withExecution(to, payload);
    await db.execute('UPDATE message_revisions SET parts=? WHERE id=?', [
      MessagePart.encode(parts),
      activity.revisionId,
    ]);
    return true;
  });
}
