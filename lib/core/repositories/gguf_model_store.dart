import 'package:servllama/core/database/model_selection_cleanup.dart';
import 'dart:convert';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_descriptor.dart';
import 'package:servllama/core/utils/new_id.dart';

/// GGUF details and the shared asset identity live in the same SQLite row.
/// This store never reads, moves or deletes model files.
class GgufModelStore {
  GgufModelStore(this.db);
  final AppDatabase db;
  static const _scope =
      "kind='llm' AND engine='llama_cpp' AND storage_owner='app'";

  Future<List<ModelDescriptor>> list() async => (await db.query(
    "SELECT manifest FROM model_assets WHERE $_scope AND json_type(manifest,'\$.gguf')='object'",
  )).map((row) => _decode(row.read<String>('manifest'))).toList();

  Future<ModelDescriptor?> find(String id) async {
    final rows = await db.query(
      "SELECT manifest FROM model_assets WHERE $_scope AND json_extract(manifest,'\$.gguf.id')=?",
      [id],
    );
    return rows.isEmpty ? null : _decode(rows.single.read<String>('manifest'));
  }

  static ModelDescriptor _decode(String manifest) => ModelDescriptor.fromJson(
    Map<String, dynamic>.from(jsonDecode(manifest)['gguf'] as Map),
  );

  Future<void> save(ModelDescriptor model) => db.transaction(() async {
    final rows = await db.query(
      "SELECT id,manifest FROM model_assets WHERE $_scope AND (json_extract(manifest,'\$.libraryId')=? OR path=?)",
      ['gguf:${model.id}', model.storedFilePath],
    );
    if (rows.length > 1) throw StateError('Conflicting GGUF asset identities');
    final previous = rows.isEmpty ? null : rows.single;
    final manifest = <String, dynamic>{
      if (previous != null)
        ...jsonDecode(previous.read<String>('manifest'))
            as Map<String, dynamic>,
      'libraryId': 'gguf:${model.id}',
      'images': model.activeMmprojFilePath != null,
      'tools': false,
      'gguf': model.toJson(),
    };
    await db.execute(
      'INSERT INTO model_assets(id,kind,engine,runtime_id,storage_owner,path,name,revision,state,manifest) '
      "VALUES(?,'llm','llama_cpp',?,'app',?,?,?,'ready',?) "
      'ON CONFLICT(id) DO UPDATE SET runtime_id=excluded.runtime_id,path=excluded.path,'
      'name=excluded.name,revision=excluded.revision,state=excluded.state,manifest=excluded.manifest',
      [
        previous?.read<String>('id') ?? newId(),
        model.modelName,
        model.storedFilePath,
        model.modelName,
        model.revision ?? 'local',
        jsonEncode(manifest),
      ],
    );
  });

  Future<void> remove(String id) => db.transaction(() async {
    await db.execute(
      "UPDATE model_assets SET state='missing',manifest=json_remove(manifest,'\$.gguf') "
      "WHERE $_scope AND json_extract(manifest,'\$.gguf.id')=?",
      [id],
    );
    await clearMissingLocalChatTargets(db);
  });
}
