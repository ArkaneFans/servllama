import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Explicit, versioned SQL keeps the legacy Hive generator independent of Drift.
/// Domain repositories own serialization; no generic object/EAV business store.
class AppDatabase extends GeneratedDatabase {
  AppDatabase(super.executor);
  factory AppDatabase.at(Directory directory) => AppDatabase(
    LazyDatabase(() async {
      final folder = Directory(p.join(directory.path, 'data'));
      await folder.create(recursive: true);
      return NativeDatabase.createInBackground(
        File(p.join(folder.path, 'servllama-v2.sqlite')),
      );
    }),
  );
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());
  static Future<AppDatabase>? _shared;
  static AppDatabase? current;
  static Future<AppDatabase> shared() => _shared ??= () async {
    final directory = await getApplicationSupportDirectory();
    return current = AppDatabase.at(directory);
  }();

  @override
  int get schemaVersion => 5;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (_) => _createSchema(),
    onUpgrade: (_, from, to) => _createSchema(),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
    },
  );
  Future<void> _createSchema() async {
    for (final statement in _schema) {
      await customStatement(statement);
    }
  }

  Future<List<QueryRow>> query(String sql, [List<Object> values = const []]) =>
      customSelect(sql, variables: values.map(_variable).toList()).get();
  Future<int> execute(String sql, [List<Object?> values = const []]) =>
      customUpdate(sql, variables: values.map(_variable).toList());
  static Variable _variable(Object? value) => switch (value) {
    int value => Variable<int>(value),
    double value => Variable<double>(value),
    bool value => Variable<bool>(value),
    String value => Variable<String>(value),
    null => const Variable<String>(null),
    _ => throw ArgumentError.value(value, 'SQL value'),
  };
  Future<String?> metadata(String key) async {
    final rows = await query('SELECT value FROM app_metadata WHERE key = ?', [
      key,
    ]);
    return rows.isEmpty ? null : rows.single.read<String>('value');
  }

  Future<void> setMetadata(String key, String value) async {
    await execute(
      'INSERT INTO app_metadata(key,value) VALUES (?,?) '
      'ON CONFLICT(key) DO UPDATE SET value=excluded.value',
      [key, value],
    );
  }

  static const _schema = [
    'CREATE TABLE IF NOT EXISTS download_tasks (id TEXT PRIMARY KEY,created_at INTEGER NOT NULL,payload TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS speech_jobs (id TEXT PRIMARY KEY,state TEXT NOT NULL,asset_id TEXT NOT NULL,created_at INTEGER NOT NULL,payload TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS voice_profiles (id TEXT PRIMARY KEY,name TEXT NOT NULL,asset_id TEXT NOT NULL,payload TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS skills (id TEXT PRIMARY KEY,name TEXT NOT NULL,hash TEXT NOT NULL,config TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS mcp_servers (id TEXT PRIMARY KEY,name TEXT NOT NULL,revision INTEGER NOT NULL,config TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS tool_invocations (id TEXT PRIMARY KEY,run_id TEXT NOT NULL,call_id TEXT NOT NULL,conversation_id TEXT NOT NULL,name TEXT NOT NULL,state TEXT NOT NULL,payload TEXT NOT NULL,created_at INTEGER NOT NULL,UNIQUE(run_id,call_id))',
    'CREATE INDEX IF NOT EXISTS invocations_conversation ON tool_invocations(conversation_id,created_at)',

    'CREATE TABLE IF NOT EXISTS assistants (id TEXT PRIMARY KEY,name TEXT NOT NULL,revision INTEGER NOT NULL,config TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS ai_connections (id TEXT PRIMARY KEY,name TEXT NOT NULL,revision INTEGER NOT NULL,config TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS generation_runs (id TEXT PRIMARY KEY,conversation_id TEXT NOT NULL,message_id TEXT NOT NULL,state TEXT NOT NULL,snapshot TEXT NOT NULL,checkpoint TEXT NOT NULL,updated_at INTEGER NOT NULL)',
    'CREATE INDEX IF NOT EXISTS runs_conversation ON generation_runs(conversation_id,updated_at)',

    'CREATE TABLE IF NOT EXISTS app_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    'CREATE TABLE IF NOT EXISTS conversations ('
        'id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL, '
        'updated_at INTEGER NOT NULL, message_ids TEXT NOT NULL, config TEXT NOT NULL DEFAULT \'{}\')',
    'CREATE TABLE IF NOT EXISTS messages ('
        'id TEXT PRIMARY KEY, conversation_id TEXT, role TEXT NOT NULL, '
        'created_at INTEGER NOT NULL, payload TEXT NOT NULL)',
    'CREATE INDEX IF NOT EXISTS messages_conversation ON messages(conversation_id, created_at)',
    'CREATE TABLE IF NOT EXISTS message_revisions ('
        'id TEXT PRIMARY KEY, message_id TEXT NOT NULL, created_at INTEGER NOT NULL, payload TEXT NOT NULL)',
    'CREATE INDEX IF NOT EXISTS revisions_message ON message_revisions(message_id)',
    'CREATE TABLE IF NOT EXISTS model_assets ('
        'id TEXT PRIMARY KEY, kind TEXT NOT NULL, engine TEXT NOT NULL, runtime_id TEXT NOT NULL, '
        'storage_owner TEXT NOT NULL, path TEXT NOT NULL, name TEXT NOT NULL, '
        'revision TEXT NOT NULL, state TEXT NOT NULL, manifest TEXT NOT NULL)',
    'CREATE UNIQUE INDEX IF NOT EXISTS asset_storage ON model_assets(engine,path)',
    'CREATE TABLE IF NOT EXISTS artifacts ('
        'id TEXT PRIMARY KEY, path TEXT UNIQUE NOT NULL, mime_type TEXT NOT NULL, '
        'owner_kind TEXT NOT NULL, owner_id TEXT NOT NULL, hash TEXT NOT NULL, '
        'size INTEGER NOT NULL, state TEXT NOT NULL DEFAULT \'ready\')',
  ];
}
