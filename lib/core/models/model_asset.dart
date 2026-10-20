import 'dart:convert';
import 'package:drift/drift.dart';

enum AssetKind { llm, asr, tts }

class ModelAsset {
  const ModelAsset({
    required this.id,
    required this.kind,
    required this.engine,
    required this.runtimeId,
    required this.storageOwner,
    required this.path,
    required this.name,
    required this.revision,
    this.state = 'ready',
    this.manifest = const {},
  });
  final String id, engine, runtimeId, storageOwner, path, name, revision, state;
  final AssetKind kind;
  final Map<String, dynamic> manifest;
  bool get isReady => state == 'ready';
  factory ModelAsset.fromRow(QueryRow r) => ModelAsset(
    id: r.read('id'),
    kind: AssetKind.values.byName(r.read('kind')),
    engine: r.read('engine'),
    runtimeId: r.read('runtime_id'),
    storageOwner: r.read('storage_owner'),
    path: r.read('path'),
    name: r.read('name'),
    revision: r.read('revision'),
    state: r.read('state'),
    manifest: jsonDecode(r.read<String>('manifest')),
  );
}
