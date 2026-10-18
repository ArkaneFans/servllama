import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/models/mcp_connection.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/mcp_client.dart';

class McpActiveConnection {
  const McpActiveConnection({required this.client, required this.tools});

  final McpClient client;
  final List<Map<String, dynamic>> tools;
}

/// App-scoped MCP sessions. Configuration changes replace stale sessions, and
/// chat runs borrow the same clients instead of creating short-lived copies.
class McpConnectionManager extends ChangeNotifier {
  McpConnectionManager({
    required AgentRepository repository,
    required Future<McpCredentials> Function(McpServer server) credentialsFor,
    AppLogger? logger,
  }) : _repository = repository,
       _credentialsFor = credentialsFor,
       _logger = logger ?? AppLogger.instance;

  final AgentRepository _repository;
  final Future<McpCredentials> Function(McpServer server) _credentialsFor;
  final AppLogger _logger;
  final Map<String, _McpSession> _sessions = {};
  final Set<void Function(String serverId)> _toolChangeListeners = {};

  Future<void>? _loading;
  bool _started = false;
  bool _loaded = false;
  bool _disposed = false;

  bool get loaded => _loaded;
  List<McpServer> get servers =>
      List.unmodifiable(_sessions.values.map((session) => session.server));

  McpServer? serverFor(String id) => _sessions[id]?.server;
  McpConnectionState stateFor(String id) =>
      _sessions[id]?.state ?? const McpConnectionState();

  void addToolChangeListener(void Function(String serverId) listener) {
    if (!_disposed) _toolChangeListeners.add(listener);
  }

  void removeToolChangeListener(void Function(String serverId) listener) {
    _toolChangeListeners.remove(listener);
  }

  Future<void> load() {
    final active = _loading;
    if (active != null) return active;
    late final Future<void> future;
    future = _load().whenComplete(() {
      if (identical(_loading, future)) _loading = null;
    });
    _loading = future;
    return future;
  }

  Future<void> _load() async {
    final records = await _repository.servers();
    if (_disposed) return;
    final incoming = {for (final server in records) server.id: server};
    for (final id in _sessions.keys.toList()) {
      if (!incoming.containsKey(id)) _remove(id);
    }
    for (final server in records) {
      final existing = _sessions[server.id];
      if (existing == null) {
        _sessions[server.id] = _McpSession(server);
      } else {
        _updateServer(existing, server);
      }
    }
    _loaded = true;
    _notify();
  }

  /// Loads the catalog and starts the app-level sessions without delaying app
  /// startup on remote network calls.
  Future<void> start() async {
    if (_disposed) return;
    _started = true;
    try {
      await load();
    } catch (error) {
      _logger.event(
        'agent.mcp.manager_load_failed',
        channel: LogChannel.agent,
        level: LogLevel.error,
        fields: AppLogger.errorFields(error),
      );
      return;
    }
    for (final session in _sessions.values.toList()) {
      unawaited(_ensureConnected(session));
    }
  }

  /// Re-checks every configured server. Existing sessions refresh their tool
  /// catalogs; failed or disconnected servers are connected again.
  Future<void> refreshAll() async {
    if (_disposed) return;
    _started = true;
    await load();
    await Future.wait(_sessions.values.map(_refreshSession));
  }

  void upsert(McpServer server) {
    if (_disposed) return;
    final existing = _sessions[server.id];
    if (existing == null) {
      final session = _McpSession(server);
      _sessions[server.id] = session;
      _notify();
      if (_started) unawaited(_ensureConnected(session));
      return;
    }
    final reconnect = _connectionChanged(existing.server, server);
    _updateServer(existing, server);
    if (reconnect && _started) unawaited(_ensureConnected(existing));
  }

  void remove(String id) {
    if (_disposed) return;
    _remove(id);
  }

  Future<McpActiveConnection> ensureConnected(
    McpServer server, {
    bool refreshTools = false,
  }) async {
    if (_disposed) throw StateError('MCP manager is closed');
    final session = _sessions[server.id];
    if (session == null) {
      upsert(server);
    } else {
      _updateServer(session, server);
    }
    final current = _sessions[server.id]!;
    final connected = await _ensureConnected(current);
    final client = current.client;
    if (!connected || client == null || !client.isConnected) {
      throw StateError(
        current.state.error ?? 'MCP connection failed for ${server.name}',
      );
    }
    if (refreshTools) {
      await _refreshToolsForRun(current);
    }
    return McpActiveConnection(
      client: current.client!,
      tools: List.unmodifiable(current.tools),
    );
  }

  void _updateServer(_McpSession session, McpServer server) {
    final reconnect = _connectionChanged(session.server, server);
    session.server = server;
    if (!reconnect) {
      if (session.client == null) {
        session.state = session.state.copyWith(toolCount: server.tools.length);
      }
      _notify();
      return;
    }
    session.generation++;
    session.connectFuture = null;
    final client = session.client;
    session.client = null;
    session.tools = const [];
    session.state = McpConnectionState(toolCount: server.tools.length);
    _notify();
    if (client != null) unawaited(client.close());
  }

  bool _connectionChanged(McpServer previous, McpServer next) =>
      previous.url != next.url ||
      previous.transport != next.transport ||
      previous.secretRef != next.secretRef;

  Future<bool> _ensureConnected(_McpSession session) async {
    final active = session.connectFuture;
    if (active != null) {
      await active;
      return session.state.isConnected && session.client != null;
    }
    if (session.client?.isConnected == true) return true;
    if (session.client != null) {
      final stale = session.client;
      session.client = null;
      session.tools = const [];
      unawaited(stale?.close());
    }
    late final Future<void> future;
    future = _connect(session).whenComplete(() {
      if (identical(session.connectFuture, future)) {
        session.connectFuture = null;
      }
    });
    session.connectFuture = future;
    try {
      await future;
      return session.state.isConnected && session.client != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _connect(_McpSession session) async {
    final generation = session.generation;
    _setState(
      session,
      session.state.copyWith(
        status: McpConnectionStatus.connecting,
        clearError: true,
      ),
      generation: generation,
    );
    McpClient? client;
    try {
      final credentials = await _credentialsFor(session.server);
      if (!_isCurrent(session, generation)) return;
      client = McpClient(
        session.server,
        headers: credentials.headers,
        logger: _logger,
        onToolsChanged: () {
          unawaited(_refreshToolsAfterNotification(session, generation));
        },
        onConnectionLost: (error) {
          _connectionLost(session, generation, error);
        },
      );
      await client.connect();
      final tools = await client.listTools();
      if (!_isCurrent(session, generation)) {
        await client.close();
        return;
      }
      session.client = client;
      session.tools = List.unmodifiable(tools);
      session.state = McpConnectionState(
        status: McpConnectionStatus.connected,
        toolCount: tools.length,
      );
      _notify();
    } catch (error) {
      if (client != null) await client.close();
      if (!_isCurrent(session, generation)) return;
      _setState(
        session,
        session.state.copyWith(
          status: McpConnectionStatus.failed,
          error: LogRedactor.redact(error.toString()),
        ),
        generation: generation,
      );
      rethrow;
    }
  }

  Future<void> _refreshSession(_McpSession session) async {
    final connectFuture = session.connectFuture;
    if (connectFuture != null) {
      await connectFuture;
      return;
    }
    if (session.client == null) {
      await _ensureConnected(session);
      return;
    }
    final generation = session.generation;
    _setState(
      session,
      session.state.copyWith(
        status: McpConnectionStatus.connecting,
        clearError: true,
      ),
      generation: generation,
    );
    try {
      final tools = await session.client!.listTools();
      if (!_isCurrent(session, generation)) return;
      session.tools = List.unmodifiable(tools);
      session.state = McpConnectionState(
        status: McpConnectionStatus.connected,
        toolCount: tools.length,
      );
      _notify();
    } catch (error) {
      if (!_isCurrent(session, generation)) return;
      final failedClient = session.client;
      session.client = null;
      session.tools = const [];
      session.state = McpConnectionState(
        status: McpConnectionStatus.failed,
        toolCount: session.server.tools.length,
        error: LogRedactor.redact(error.toString()),
      );
      _notify();
      if (failedClient != null) unawaited(failedClient.close());
    }
  }

  Future<void> _refreshToolsAfterNotification(
    _McpSession session,
    int generation,
  ) async {
    final client = session.client;
    if (client == null || !_isCurrent(session, generation)) return;
    try {
      final tools = await client.listTools();
      if (!_isCurrent(session, generation) ||
          !identical(session.client, client)) {
        return;
      }
      session.tools = List.unmodifiable(tools);
      session.state = session.state.copyWith(
        status: McpConnectionStatus.connected,
        toolCount: tools.length,
        clearError: true,
      );
      _notify();
      for (final listener in _toolChangeListeners.toList()) {
        listener(session.server.id);
      }
    } catch (error) {
      if (!_isCurrent(session, generation) ||
          !identical(session.client, client)) {
        return;
      }
      _connectionLost(session, generation, error);
    }
  }

  Future<void> _refreshToolsForRun(_McpSession session) async {
    final client = session.client;
    if (client == null) return;
    final generation = session.generation;
    try {
      final tools = await client.listTools();
      if (!_isCurrent(session, generation) ||
          !identical(session.client, client)) {
        return;
      }
      session.tools = List.unmodifiable(tools);
      session.state = session.state.copyWith(
        status: McpConnectionStatus.connected,
        toolCount: tools.length,
        clearError: true,
      );
      _notify();
    } catch (error) {
      _connectionLost(session, generation, error);
      rethrow;
    }
  }

  void _connectionLost(_McpSession session, int generation, Object error) {
    if (!_isCurrent(session, generation) || session.client == null) return;
    final client = session.client;
    session.client = null;
    session.tools = const [];
    session.state = McpConnectionState(
      status: McpConnectionStatus.failed,
      toolCount: session.server.tools.length,
      error: LogRedactor.redact(error.toString()),
    );
    _notify();
    if (client != null) unawaited(client.close());
  }

  bool _isCurrent(_McpSession session, int generation) =>
      !_disposed &&
      identical(_sessions[session.server.id], session) &&
      session.generation == generation;

  void _setState(
    _McpSession session,
    McpConnectionState state, {
    required int generation,
  }) {
    if (!_isCurrent(session, generation)) return;
    session.state = state;
    _notify();
  }

  void _remove(String id) {
    final session = _sessions.remove(id);
    if (session == null) return;
    session.generation++;
    final client = session.client;
    session.client = null;
    _notify();
    if (client != null) unawaited(client.close());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final session in _sessions.values) {
      session.generation++;
      final client = session.client;
      session.client = null;
      if (client != null) unawaited(client.close());
    }
    _sessions.clear();
    _toolChangeListeners.clear();
    super.dispose();
  }
}

class _McpSession {
  _McpSession(this.server)
    : state = McpConnectionState(toolCount: server.tools.length);

  McpServer server;
  McpConnectionState state;
  McpClient? client;
  List<Map<String, dynamic>> tools = const [];
  Future<void>? connectFuture;
  int generation = 0;
}
