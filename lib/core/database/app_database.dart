import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

@DataClassName('DbAssistants', companion: 'AssistantsCompanion')
class Assistants extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get revision => integer()();
  TextColumn get config => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DbAiConnections', companion: 'AiConnectionsCompanion')
class AiConnections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get revision => integer()();
  TextColumn get config => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DbSkills', companion: 'SkillsCompanion')
class Skills extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get hash => text()();
  TextColumn get config => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DbMcpServers', companion: 'McpServersCompanion')
class McpServers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get revision => integer()();
  TextColumn get config => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'conversations_recent',
  columns: {
    IndexedColumn(#updatedAt, orderBy: OrderingMode.desc),
    #id,
  },
)
@TableIndex(
  name: 'conversations_assistant',
  columns: {
    #assistantId,
    IndexedColumn(#updatedAt, orderBy: OrderingMode.desc),
  },
)
@DataClassName('DbConversations', companion: 'ConversationsCompanion')
class Conversations extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get assistantId => text().nullable().references(
    Assistants,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DbMessages', companion: 'MessagesCompanion')
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get role =>
      text()
      // ignore: recursive_getters
      .check(role.isIn(['user', 'assistant']))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'UNIQUE (conversation_id, position)',
  ];
}

@TableIndex(name: 'revisions_run', columns: {#runId})
@TableIndex.sql(
  'CREATE UNIQUE INDEX revisions_selected '
  'ON message_revisions(message_id) WHERE is_selected = 1',
)
@DataClassName('DbMessageRevisions', companion: 'MessageRevisionsCompanion')
class MessageRevisions extends Table {
  TextColumn get id => text()();
  TextColumn get messageId =>
      text().references(Messages, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get runId => text().nullable().references(
    GenerationRuns,
    #id,
    initiallyDeferred: true,
  )();
  IntColumn get isDraft => integer()
      // ignore: recursive_getters
      .check(isDraft.isIn([0, 1]))
      .withDefault(const Constant(0))();
  IntColumn get isSelected => integer()
      // ignore: recursive_getters
      .check(isSelected.isIn([0, 1]))
      .withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  TextColumn get content => text()();
  TextColumn get reasoningContent => text().nullable()();
  TextColumn get modelName => text().nullable()();
  TextColumn get author => text().nullable()();
  TextColumn get generationMetrics => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const ['UNIQUE (message_id, position)'];
}

@TableIndex(name: 'attachments_path', columns: {#path})
@DataClassName(
  'DbRevisionAttachments',
  companion: 'RevisionAttachmentsCompanion',
)
class RevisionAttachments extends Table {
  TextColumn get revisionId =>
      text().references(MessageRevisions, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get path => text()();

  @override
  Set<Column<Object>> get primaryKey => {revisionId, position};
}

@TableIndex(
  name: 'runs_conversation',
  columns: {
    #conversationId,
    IndexedColumn(#updatedAt, orderBy: OrderingMode.desc),
  },
)
@TableIndex.sql(
  'CREATE INDEX runs_active ON generation_runs(state) '
  "WHERE state IN ('running', 'awaitingApproval', 'cancelling')",
)
@DataClassName('DbGenerationRuns', companion: 'GenerationRunsCompanion')
class GenerationRuns extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId =>
      text().references(Conversations, #id, onDelete: KeyAction.cascade)();
  TextColumn get state => text()();
  TextColumn get snapshot => text()();
  TextColumn get checkpoint => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'invocations_run', columns: {#runId, #createdAt})
@DataClassName('DbToolInvocations', companion: 'ToolInvocationsCompanion')
class ToolInvocations extends Table {
  TextColumn get id => text()();
  TextColumn get runId =>
      text().references(GenerationRuns, #id, onDelete: KeyAction.cascade)();
  TextColumn get callId => text()();
  TextColumn get name => text()();
  TextColumn get state => text()();
  TextColumn get payload => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const ['UNIQUE (run_id, call_id)'];
}

@DataClassName('DbChatDrafts', companion: 'ChatDraftsCompanion')
class ChatDrafts extends Table {
  TextColumn get key => text()();
  TextColumn get conversationId => text()
      .nullable()
      .references(Conversations, #id, onDelete: KeyAction.cascade)
      .unique()();
  TextColumn get assistantId => text()
      .nullable()
      .references(Assistants, #id, onDelete: KeyAction.cascade)
      .unique()();
  TextColumn get content => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};

  @override
  List<String> get customConstraints => const [
    'CHECK ((conversation_id IS NULL) != (assistant_id IS NULL))',
  ];
}

@DataClassName('DbModelAssets', companion: 'ModelAssetsCompanion')
class ModelAssets extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get engine => text()();
  TextColumn get runtimeId => text()();
  TextColumn get storageOwner => text()();
  TextColumn get path => text()();
  TextColumn get name => text()();
  TextColumn get revision => text()();
  TextColumn get state => text()();
  TextColumn get manifest => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => const ['UNIQUE (engine, path)'];
}

@TableIndex(
  name: 'speech_jobs_recent',
  columns: {
    IndexedColumn(#createdAt, orderBy: OrderingMode.desc),
    #id,
  },
)
@TableIndex(name: 'speech_jobs_asset', columns: {#assetId, #state})
@TableIndex(name: 'speech_jobs_voice', columns: {#voiceId, #state})
@TableIndex(name: 'speech_jobs_state', columns: {#state})
@DataClassName('DbSpeechJobs', companion: 'SpeechJobsCompanion')
class SpeechJobs extends Table {
  TextColumn get id => text()();
  TextColumn get state => text()();
  TextColumn get assetId => text()();
  TextColumn get voiceId => text().nullable()();
  IntColumn get createdAt => integer()();
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'voices_name', columns: {#name, #id})
@DataClassName('DbVoiceProfiles', companion: 'VoiceProfilesCompanion')
class VoiceProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get assetId => text()();
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'downloads_recent',
  columns: {
    IndexedColumn(#createdAt, orderBy: OrderingMode.desc),
    #id,
  },
)
@DataClassName('DbDownloadTasks', companion: 'DownloadTasksCompanion')
class DownloadTasks extends Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()();
  TextColumn get payload => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName(
  'DbPendingFileDeletions',
  companion: 'PendingFileDeletionsCompanion',
)
class PendingFileDeletions extends Table {
  TextColumn get path => text()();
  TextColumn get kind =>
      text()
      // ignore: recursive_getters
      .check(kind.isIn(['chatAttachment', 'speechJob', 'voiceProfile']))();

  @override
  Set<Column<Object>> get primaryKey => {path};
}

@DataClassName('DbAppMetadata', companion: 'AppMetadataCompanion')
class AppMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Assistants,
    AiConnections,
    Skills,
    McpServers,
    Conversations,
    Messages,
    MessageRevisions,
    RevisionAttachments,
    GenerationRuns,
    ToolInvocations,
    ChatDrafts,
    ModelAssets,
    SpeechJobs,
    VoiceProfiles,
    DownloadTasks,
    PendingFileDeletions,
    AppMetadata,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);
  factory AppDatabase.at(Directory directory) => AppDatabase(
    LazyDatabase(() async {
      final folder = Directory(p.join(directory.path, 'data'));
      await folder.create(recursive: true);
      return NativeDatabase.createInBackground(
        File(p.join(folder.path, 'servllama.sqlite')),
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
  int get schemaVersion => 2;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(
          messageRevisions,
          messageRevisions.generationMetrics,
        );
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );

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
}
