import 'dart:convert';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/speech/models/speech_models.dart';

class SpeechRepository {
  SpeechRepository(this.db);
  final AppDatabase db;
  static const activeStates = "('queued','waiting','running','cancelling')";
  Future<List<SpeechJob>> jobs() async =>
      (await db.query(
            'SELECT payload FROM speech_jobs ORDER BY created_at DESC,id',
          ))
          .map((r) => SpeechJob.fromJson(jsonDecode(r.read<String>('payload'))))
          .toList();
  Future<void> saveJob(SpeechJob j) async {
    await db.execute(
      'INSERT INTO speech_jobs(id,state,asset_id,voice_id,created_at,payload) VALUES(?,?,?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET state=excluded.state,asset_id=excluded.asset_id,'
      'voice_id=excluded.voice_id,payload=excluded.payload',
      [
        j.id,
        j.state.name,
        j.assetId,
        (j.snapshot['voice'] as Map?)?['id'] as String?,
        j.createdAt.millisecondsSinceEpoch,
        jsonEncode(j.toJson()),
      ],
    );
  }

  Future<void> recover() async {
    await db.transaction(() async {
      for (final row in await db.query(
        'SELECT payload FROM speech_jobs WHERE state IN $activeStates',
      )) {
        final j = SpeechJob.fromJson(jsonDecode(row.read<String>('payload')));
        await saveJob(
          j.copyWith(
            state: SpeechJobState.interrupted,
            error: 'Process stopped; no automatic replay',
          ),
        );
      }
    });
  }

  Future<int> activeCount() async => (await db.query(
    'SELECT count(*) AS total FROM speech_jobs WHERE state IN $activeStates',
  )).single.read<int>('total');
  Future<bool> usesAsset(String id) async => (await db.query(
    'SELECT 1 FROM speech_jobs WHERE asset_id=? AND state IN $activeStates LIMIT 1',
    [id],
  )).isNotEmpty;
  Future<bool> usesVoice(String id) async => (await db.query(
    'SELECT 1 FROM speech_jobs WHERE voice_id=? AND state IN $activeStates LIMIT 1',
    [id],
  )).isNotEmpty;
  Future<void> deleteJob(String id) =>
      db.execute('DELETE FROM speech_jobs WHERE id=?', [id]);
  Future<List<VoiceProfile>> voices() async =>
      (await db.query('SELECT payload FROM voice_profiles ORDER BY name'))
          .map(
            (r) => VoiceProfile.fromJson(jsonDecode(r.read<String>('payload'))),
          )
          .toList();
  Future<void> saveVoice(VoiceProfile v) => db.execute(
    'INSERT INTO voice_profiles(id,name,asset_id,payload) VALUES(?,?,?,?) '
    'ON CONFLICT(id) DO UPDATE SET name=excluded.name,payload=excluded.payload',
    [v.id, v.name, v.assetId, jsonEncode(v.toJson())],
  );
  Future<void> deleteVoice(String id) =>
      db.execute('DELETE FROM voice_profiles WHERE id=?', [id]);
}
