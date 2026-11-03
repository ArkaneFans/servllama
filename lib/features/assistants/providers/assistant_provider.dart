import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:flutter/foundation.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:dio/dio.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';

class AssistantProvider extends ChangeNotifier {
  AssistantProvider({
    AssistantRepository? repository,
    UnifiedModelRepository? models,
    AppLogger? logger,
    Future<String> Function()? loadDefaultName,
  }) : _repository = repository,
       _logger = logger ?? AppLogger.instance,
       _loadDefaultName =
           loadDefaultName ??
           (() async => AppL10nService.instance.current.v2AssistantDefaultName),
       models = models ?? UnifiedModelRepository();
  final AppLogger _logger;
  final Future<String> Function() _loadDefaultName;
  AssistantRepository? _repository;
  final UnifiedModelRepository models;
  List<Assistant> assistants = [];
  List<AiConnection> connections = [];
  List<ModelAsset> assets = [];
  UserProfile profile = const UserProfile();
  String? activeId, error;
  bool loaded = false;
  bool _disposed = false;
  Future<void> _assistantUpdateQueue = Future.value();
  Assistant? get active =>
      assistants.where((a) => a.id == activeId).firstOrNull;
  Future<AssistantRepository> get repository async =>
      _repository ??= AssistantRepository(await AppDatabase.shared());
  Future<void>? _loadFuture;

  /// Metadata only: route demand joins the same initial read as startup.
  Future<void> ensureLoaded() =>
      _loadFuture ?? (loaded ? Future<void>.value() : load());

  Future<void> _requireLoaded() async {
    await ensureLoaded();
    if (_disposed || !loaded || error != null) {
      throw StateError('Application settings unavailable; retry loading');
    }
  }

  Future<void> load() =>
      _loadFuture ??= _load().whenComplete(() => _loadFuture = null);

  Future<void> _load() async {
    try {
      final r = await repository;
      await r.initializeProviders();
      var restoredAssistants = await r.assistants();
      final restoredConnections = await r.connections();
      final restoredProfile = await r.profile();
      if (restoredAssistants.isEmpty) {
        final name = await _loadDefaultName();
        if (_disposed) return;
        final initial = Assistant(id: newId(), name: name);
        await r.saveAssistant(initial);
        restoredAssistants = [initial];
      }
      final savedId = await r.preferences.getString('v2.activeAssistant');
      final restoredId =
          restoredAssistants.any((a) => a.id == (activeId ?? savedId))
          ? activeId ?? savedId!
          : restoredAssistants.first.id;
      if (savedId != restoredId) {
        await r.preferences.setString('v2.activeAssistant', restoredId);
      }
      final restoredAssets = await models.listAssets();
      await r.clearMissingTargets();
      restoredAssistants = await r.assistants();
      if (_disposed) return;
      assistants = restoredAssistants;
      connections = restoredConnections;
      profile = restoredProfile;
      activeId = restoredId;
      assets = restoredAssets;
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
    await _requireLoaded();
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
    await _requireLoaded();
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

  Future<Assistant> updateAssistant(String id, Map<String, dynamic> changes) {
    final result = _assistantUpdateQueue.then((_) async {
      await _requireLoaded();
      final updated = await (await repository).updateAssistant(id, changes);
      assistants = await (await repository).assistants();
      await AgentToolService.current?.revalidate();
      notifyListeners();
      return updated;
    });
    _assistantUpdateQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
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
    await _requireLoaded();
    await (await repository).setChatTarget(id, target);
    assistants = await (await repository).assistants();
    notifyListeners();
  }

  Future<void> duplicate(Assistant a) =>
      save(a.changed({'id': newId(), 'revision': 1, 'name': '${a.name} (2)'}));
  Future<void> saveConnection(AiConnection c, {String? key}) async {
    await _requireLoaded();
    try {
      await (await repository).saveConnection(c, key: key);
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
    await _requireLoaded();
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
    await _requireLoaded();
    await (await repository).saveProfile(p);
    _logger.event('client.profile.saved', channel: LogChannel.client);
    profile = p;
    await AgentToolService.current?.revalidate();
    notifyListeners();
  }

  AiConnection? connection(String? id) =>
      connections.where((c) => c.id == id).firstOrNull;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<List<String>> discover(
    AiConnection draft,
    String typedKey, {
    CancelToken? cancelToken,
  }) async {
    final client = ChatProtocolClient(logger: _logger);
    try {
      return await client.listModels(
        draft,
        typedKey.isNotEmpty ? typedKey : draft.apiKey,
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
    CancelToken? cancelToken,
  }) async {
    final client = ChatProtocolClient(logger: _logger);
    try {
      await client.test(
        draft,
        typedKey.isNotEmpty ? typedKey : draft.apiKey,
        model,
        cancelToken: cancelToken,
      );
    } finally {
      client.dio.close(force: true);
    }
  }

  Future<void>? _assetRefresh;

  Future<void> refreshAssets() {
    // A committed import/delete needs a fresh read after any older prefetch.
    late final Future<void> refreshing;
    refreshing = (_assetRefresh ?? Future<void>.value())
        .then((_) {}, onError: (Object _) {})
        .then((_) => _refreshAssets())
        .whenComplete(() {
          if (identical(_assetRefresh, refreshing)) _assetRefresh = null;
        });
    _assetRefresh = refreshing;
    return refreshing;
  }

  Future<void> _refreshAssets() async {
    await _requireLoaded();
    final refreshed = await models.listAssets();
    final r = await repository;
    await r.clearMissingTargets();
    final current = await r.assistants();
    assets = refreshed;
    assistants = current;
    await AgentToolService.current?.revalidate();
    notifyListeners();
  }
}
