import 'dart:convert';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/security/secret_store.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/models/avatar_data.dart';
import 'package:servllama/features/assistants/models/provider_presets.dart';

class AssistantRepository {
  AssistantRepository(this.db, {SecretStore? secrets, KvStorage? preferences})
    : secrets = secrets ?? SecretStore.instance,
      preferences = preferences ?? KvStorage.instance;
  final AppDatabase db;
  final SecretStore secrets;
  final KvStorage preferences;
  Future<void> initializeProviders() async {
    await db.transaction(() async {
      for (final preset in providerPresets) {
        await db.execute(
          'INSERT OR IGNORE INTO ai_connections(id,name,revision,config) VALUES(?,?,?,?)',
          [
            preset.id,
            preset.name,
            preset.revision,
            jsonEncode(preset.toJson()),
          ],
        );
      }
    });
  }

  Future<List<Assistant>> assistants() async =>
      (await db.query('SELECT config FROM assistants ORDER BY name'))
          .map((r) => Assistant.fromJson(jsonDecode(r.read<String>('config'))))
          .toList();
  Future<List<AiConnection>> connections() async =>
      (await db.query('SELECT config FROM ai_connections ORDER BY name'))
          .map(
            (r) => AiConnection.fromJson(jsonDecode(r.read<String>('config'))),
          )
          .toList();
  Future<void> saveAssistantEdit(Assistant a, {int? expectedRevision}) =>
      db.transaction(() async {
        if (expectedRevision != null) {
          final current = (await assistants())
              .where((v) => v.id == a.id)
              .firstOrNull;
          if (current == null || current.revision != expectedRevision) {
            throw StateError('Assistant changed; reopen its settings');
          }
        }
        await validateTarget(a.chatTarget);
        await saveAssistant(a);
      });

  Future<void> saveAssistant(Assistant a) async {
    AvatarData.validate(a.avatar);
    a.webSearch.validate();
    if (a.chatTarget != null && !a.chatTarget!.isConfigured) {
      throw const FormatException('Invalid chat model');
    }
    if (a.name.trim().isEmpty ||
        a.name.length > 120 ||
        a.instructions.length > 65536 ||
        a.maxTokens < 1 ||
        a.maxTokens > 32768 ||
        a.maxTurns < 1 ||
        a.maxTurns > 16 ||
        a.maxToolCalls < 0 ||
        a.maxToolCalls > 32 ||
        a.temperature < 0 ||
        a.temperature > 2 ||
        a.contextChars < 1000 ||
        a.contextChars > 256000 ||
        a.timeoutSeconds < 10 ||
        a.timeoutSeconds > 1800) {
      throw const FormatException('Invalid assistant configuration');
    }
    await db.execute(
      'INSERT INTO assistants(id,name,revision,config) VALUES(?,?,?,?) '
      'ON CONFLICT(id) DO UPDATE SET name=excluded.name,revision=excluded.revision,config=excluded.config',
      [a.id, a.name, a.revision, jsonEncode(a.toJson())],
    );
  }

  Future<void> validateTarget(ChatTarget? target) async {
    if (target == null) return;
    if (!target.isConfigured) throw StateError('Choose a model');
    if (target.isRemote) {
      final provider = (await connections())
          .where((c) => c.id == target.connectionId)
          .firstOrNull;
      if (provider?.hasModel(target.modelId) != true) {
        throw StateError('Model unavailable; select another model');
      }
    } else {
      final rows = await db.query(
        "SELECT id FROM model_assets WHERE id=? AND kind='llm' AND state='ready'",
        [target.assetId!],
      );
      if (rows.isEmpty) throw StateError('Local model unavailable');
    }
  }

  Future<void> setChatTarget(String id, ChatTarget? target) => db.transaction(
    () async {
      final current = (await assistants()).where((a) => a.id == id).firstOrNull;
      if (current == null) throw StateError('Assistant unavailable');
      await validateTarget(target);
      await saveAssistant(
        current.changed({
          'chatTarget': target?.toJson(),
          'revision': current.revision + 1,
        }),
      );
    },
  );

  Future<void> _clearTargets(bool Function(ChatTarget) matches) async {
    for (final a in await assistants()) {
      if (a.chatTarget != null && matches(a.chatTarget!)) {
        await saveAssistant(
          a.changed({'chatTarget': null, 'revision': a.revision + 1}),
        );
      }
    }
  }

  // Persist invalid references as empty; do not infer a replacement model.
  Future<void> clearMissingTargets() => db.transaction(() async {
    final providers = await connections();
    final assets = (await db.query(
      "SELECT id FROM model_assets WHERE kind='llm' AND state='ready'",
    )).map((r) => r.read<String>('id')).toSet();
    await _clearTargets(
      (t) =>
          !t.isConfigured ||
          (t.isRemote
              ? !providers.any(
                  (p) => p.id == t.connectionId && p.hasModel(t.modelId),
                )
              : !assets.contains(t.assetId)),
    );
  });

  Future<AiConnection> saveConnection(
    AiConnection c, {
    String? newSecret,
    bool clearSecret = false,
  }) async {
    c.validate();
    String? previousRef, nextRef;
    late AiConnection saved;
    try {
      saved = await db.transaction(() async {
        final previous = (await connections())
            .where((v) => v.id == c.id)
            .firstOrNull;
        if (previous != null && c.revision != previous.revision) {
          throw StateError('Provider changed; reopen its settings');
        }
        previousRef = previous?.secretRef;
        nextRef = clearSecret ? null : previousRef;
        if (newSecret != null && newSecret.isNotEmpty) {
          nextRef = 'connection:${c.id}:${newId()}';
          await secrets.write(nextRef!, newSecret);
        }
        final value = c.changed({
          'secretRef': nextRef,
          'revision': (previous?.revision ?? 0) + 1,
          'models': c.models.map((id) => id.trim()).toSet().toList(),
          'modelCapabilities': {
            for (final id in c.models)
              id.trim(): c.capabilitiesFor(id).toJson(),
          },
        });
        await db.execute(
          'INSERT INTO ai_connections(id,name,revision,config) VALUES(?,?,?,?) '
          'ON CONFLICT(id) DO UPDATE SET name=excluded.name,revision=excluded.revision,config=excluded.config',
          [value.id, value.name, value.revision, jsonEncode(value.toJson())],
        );
        await _clearTargets(
          (t) =>
              t.isRemote &&
              t.connectionId == value.id &&
              !value.hasModel(t.modelId),
        );
        return value;
      });
    } catch (_) {
      if (nextRef != null && nextRef != previousRef) {
        await secrets.delete(nextRef!);
      }
      rethrow;
    }
    if (previousRef != null && previousRef != nextRef) {
      await secrets.delete(previousRef!);
    }
    return saved;
  }

  Future<void> deleteConnection(String id) async {
    if (isPresetProvider(id)) {
      throw StateError('Preset providers cannot be deleted');
    }
    final connection = (await connections())
        .where((c) => c.id == id)
        .firstOrNull;
    await db.transaction(() async {
      await _clearTargets((t) => t.isRemote && t.connectionId == id);
      await db.execute('DELETE FROM ai_connections WHERE id=?', [id]);
    });
    if (connection?.secretRef != null) {
      await secrets.delete(connection!.secretRef!);
    }
  }

  Future<UserProfile> profile() async => UserProfile.fromJson(
    jsonDecode(await preferences.getString('v2.userProfile') ?? '{}'),
  );
  Future<void> saveProfile(UserProfile p) async {
    AvatarData.validate(p.avatar);
    if (p.name.length > 120 || p.description.length > 8000) {
      throw const FormatException('User profile exceeds its field limits');
    }
    await preferences.setString('v2.userProfile', jsonEncode(p.toJson()));
  }
}
