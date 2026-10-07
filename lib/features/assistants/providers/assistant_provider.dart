import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:flutter/foundation.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:dio/dio.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';

class AssistantProvider extends ChangeNotifier {
  AssistantProvider({
    AssistantRepository? repository,
    UnifiedModelRepository? models,
    AppLogger? logger,
  }) : _repository = repository,
       _logger = logger ?? AppLogger.instance,
       models = models ?? UnifiedModelRepository();
  final AppLogger _logger;
  AssistantRepository? _repository;
  final UnifiedModelRepository models;
  List<Assistant> assistants = [];
  List<AiConnection> connections = [];
  List<ModelAsset> assets = [];
  UserProfile profile = const UserProfile();
  String? activeId, error;
  bool loaded = false;
  Assistant? get active =>
      assistants.where((a) => a.id == activeId).firstOrNull;
  Future<AssistantRepository> get repository async =>
      _repository ??= AssistantRepository(await AppDatabase.shared());
  Future<void> load() async {
    try {
      final r = await repository;
      await r.initializeProviders();
      assistants = await r.assistants();
      connections = await r.connections();
      profile = await r.profile();
      if (assistants.isEmpty) {
        final initial = Assistant(id: newId(), name: 'ServLlama');
        await r.saveAssistant(initial);
        assistants = [initial];
      }
      final savedId = await r.preferences.getString('v2.activeAssistant');
      activeId ??= savedId;
      if (!assistants.any((a) => a.id == activeId)) {
        activeId = assistants.first.id;
      }
      if (savedId != activeId) {
        await r.preferences.setString('v2.activeAssistant', activeId!);
      }
      assets = await models.listAssets();
      await r.clearMissingTargets();
      assistants = await r.assistants();
      error = null;
      loaded = true;
    } catch (e) {
      error = LogRedactor.redact(e.toString());
      _logger.event(
        'client.settings.load_failed',
        channel: LogChannel.client,
        level: LogLevel.error,
        fields: AppLogger.errorFields(e),
      );
    }
    await AgentToolService.current?.revalidate();
    notifyListeners();
  }

  Future<void> select(String id) async {
    if (!assistants.any((a) => a.id == id)) return;
    await (await repository).preferences.setString('v2.activeAssistant', id);
    activeId = id;
    _logger.event(
      'client.assistant.selected',
      channel: LogChannel.client,
      fields: {'assistant': id},
    );
    await AgentToolService.current?.revalidate();
    notifyListeners();
  }

  Future<void> save(Assistant a, {int? expectedRevision}) async {
    await (await repository).saveAssistantEdit(
      a,
      expectedRevision: expectedRevision,
    );
    _logger.event(
      'client.assistant.saved',
      channel: LogChannel.client,
      fields: {'assistant': a.id},
    );
    assistants = await (await repository).assistants();
    await AgentToolService.current?.revalidate();
    notifyListeners();
  }

  ChatTarget? resolveTarget(ChatTarget? target) {
    if (target?.isConfigured != true) return null;
    if (target!.isRemote) {
      return connection(target.connectionId)?.hasModel(target.modelId) == true
          ? target
          : null;
    }
    return assets.any(
          (a) => a.id == target.assetId && a.kind == AssetKind.llm && a.isReady,
        )
        ? target
        : null;
  }

  Future<void> setChatTarget(String id, ChatTarget? target) async {
    await (await repository).setChatTarget(id, target);
    assistants = await (await repository).assistants();
    notifyListeners();
  }

  Future<void> duplicate(Assistant a) =>
      save(a.changed({'id': newId(), 'revision': 1, 'name': '${a.name} (2)'}));
  Future<void> saveConnection(
    AiConnection c, {
    String? key,
    bool clearKey = false,
  }) async {
    try {
      await (await repository).saveConnection(
        c,
        newSecret: key,
        clearSecret: clearKey,
      );
      _logger.event(
        'client.connection.saved',
        channel: LogChannel.client,
        fields: {'connection': c.id, 'protocol': c.protocol.name},
      );
    } catch (error) {
      _logger.event(
        'client.connection.save_failed',
        channel: LogChannel.client,
        level: LogLevel.error,
        fields: {'connection': c.id, ...AppLogger.errorFields(error)},
      );
      rethrow;
    } finally {
      connections = await (await repository).connections();
      assistants = await (await repository).assistants();
      await AgentToolService.current?.revalidate();
      notifyListeners();
    }
  }

  Future<void> deleteConnection(String id) async {
    try {
      await (await repository).deleteConnection(id);
      _logger.event(
        'client.connection.deleted',
        channel: LogChannel.client,
        fields: {'connection': id},
      );
    } catch (error) {
      _logger.event(
        'client.connection.delete_failed',
        channel: LogChannel.client,
        level: LogLevel.error,
        fields: {'connection': id, ...AppLogger.errorFields(error)},
      );
      rethrow;
    } finally {
      connections = await (await repository).connections();
      assistants = await (await repository).assistants();
      await AgentToolService.current?.revalidate();
      notifyListeners();
    }
  }

  Future<void> saveProfile(UserProfile p) async {
    await (await repository).saveProfile(p);
    _logger.event('client.profile.saved', channel: LogChannel.client);
    profile = p;
    await AgentToolService.current?.revalidate();
    notifyListeners();
  }

  AiConnection? connection(String? id) =>
      connections.where((c) => c.id == id).firstOrNull;
  Future<String> credential(AiConnection c) async => c.secretRef == null
      ? ''
      : await (await repository).secrets.read(c.secretRef!) ?? '';
  Future<List<String>> discover(
    AiConnection draft,
    String typedKey, {
    bool clearKey = false,
    CancelToken? cancelToken,
  }) async {
    final client = ChatProtocolClient(logger: _logger);
    try {
      return await client.listModels(
        draft,
        typedKey.isNotEmpty
            ? typedKey
            : clearKey
            ? ''
            : await credential(draft),
        cancelToken: cancelToken,
      );
    } finally {
      client.dio.close(force: true);
    }
  }

  Future<void> testConnection(
    AiConnection draft,
    String typedKey,
    String model, {
    bool clearKey = false,
    CancelToken? cancelToken,
  }) async {
    final client = ChatProtocolClient(logger: _logger);
    try {
      await client.test(
        draft,
        typedKey.isNotEmpty
            ? typedKey
            : clearKey
            ? ''
            : await credential(draft),
        model,
        cancelToken: cancelToken,
      );
    } finally {
      client.dio.close(force: true);
    }
  }

  Future<void> refreshAssets() async {
    assets = await models.listAssets();
    final r = await repository;
    await r.clearMissingTargets();
    assistants = await r.assistants();
    notifyListeners();
  }
}
