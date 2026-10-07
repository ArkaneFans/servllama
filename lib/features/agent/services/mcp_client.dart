import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/core/network/server_sent_events.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/features/agent/models/agent_records.dart';

/// Remote MCP transports only. A session belongs to one run or connection test.
/// No subprocesses, automatic retries, or implicit replays after session loss.
class McpClient {
  McpClient(
    this.server,
    String key, {
    Dio? dio,
    AppLogger? logger,
    this.runId,
    this.onToolsChanged,
    Map<String, String> headers = const {},
  }) : _logger = logger ?? AppLogger.instance,
       credentials = McpCredentials(token: key, headers: headers),
       dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 30),
               followRedirects: false,
             ),
           );
  final McpServer server;
  final AppLogger _logger;
  final String? runId;
  final String _logSession = newId();
  Map<String, Object?> get _logFields => {
    'server': server.id,
    'session': _logSession,
    'run': runId,
    'transport': server.transport.name,
  };
  final McpCredentials credentials;
  String get key => credentials.token;
  final Dio dio;
  final void Function()? onToolsChanged;
  final CancelToken _lifetime = CancelToken();
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  StreamSubscription<ServerEvent>? _subscription;
  final Completer<Uri> _endpoint = Completer<Uri>();
  String? _sessionId;
  String _version = '2025-03-26';
  int _sequence = 0;
  bool _closed = false;
  Uri get uri => Uri.parse(server.url);
  Map<String, String> get _headers => {
    ...credentials.headers,
    'Content-Type': 'application/json',
    'Accept': 'application/json, text/event-stream',
    if (key.isNotEmpty) 'Authorization': 'Bearer $key',
    if (_sessionId != null) 'Mcp-Session-Id': _sessionId!,
    'MCP-Protocol-Version': _version,
  };
  void _validate() {
    server.validate();
    credentials.validate();
    LogRedactor.remember(key);
    for (final value in credentials.headers.values) {
      LogRedactor.remember(value);
    }
  }

  Future<void> connect() async {
    final watch = Stopwatch()..start();
    _logger.event(
      'agent.mcp.connect_started',
      channel: LogChannel.agent,
      fields: _logFields,
    );
    try {
      await _connect();
      _logger.event(
        'agent.mcp.connected',
        channel: LogChannel.agent,
        fields: {..._logFields, 'elapsed_ms': watch.elapsedMilliseconds},
      );
    } catch (error) {
      _logger.event(
        'agent.mcp.connect_failed',
        channel: LogChannel.agent,
        level: LogLevel.error,
        fields: {
          ..._logFields,
          'elapsed_ms': watch.elapsedMilliseconds,
          ...AppLogger.errorFields(error),
        },
      );
      rethrow;
    }
  }

  Future<void> _connect() async {
    _endpoint.future.ignore();
    _validate();
    if (server.transport == McpTransport.sse) {
      await _openEvents(uri, legacy: true);
      await _endpoint.future.timeout(const Duration(seconds: 20));
    }
    final result = await request('initialize', {
      'protocolVersion': _version,
      'capabilities': {},
      'clientInfo': {'name': 'ServLlama', 'version': '2.0.0'},
    });
    final version = result['protocolVersion'] as String?;
    if (!['2024-11-05', '2025-03-26', '2025-06-18'].contains(version)) {
      throw StateError('Unsupported MCP protocol version');
    }
    _version = version!;
    await notify('notifications/initialized', {});
    if (server.transport == McpTransport.streamableHttp) {
      // GET is optional. tools/list before execution also detects catalog changes.
      try {
        await _openEvents(uri, legacy: false);
      } on DioException catch (_) {
        /* Optional event stream. */
      }
    }
  }

  Future<void> _openEvents(Uri endpoint, {required bool legacy}) async {
    final r = await dio.get<ResponseBody>(
      endpoint.toString(),
      cancelToken: _lifetime,
      options: Options(
        headers: _headers,
        responseType: ResponseType.stream,
        receiveTimeout: Duration.zero,
        validateStatus: (_) => true,
      ),
    );
    if (r.statusCode != 200 || r.data == null) {
      if (legacy) throw StateError('MCP SSE connection failed');
      await r.data?.stream.drain<void>();
      return;
    }
    _subscription = decodeServerEvents(r.data!.stream).listen(
      (e) {
        try {
          if (e.event == 'endpoint') {
            final target = uri.resolve(e.data);
            if (target.origin != uri.origin) {
              throw const FormatException('MCP endpoint changed origin');
            }
            if (!_endpoint.isCompleted) _endpoint.complete(target);
          } else if (e.data.isNotEmpty) {
            _deliver(jsonDecode(e.data) as Map<String, dynamic>);
          }
        } catch (error, stack) {
          _failPending(error, stack);
        }
      },
      onError: (Object error, StackTrace stack) => _failPending(error, stack),
      onDone: () {
        if (!_closed) {
          _failPending(
            StateError('MCP event stream closed'),
            StackTrace.current,
          );
        }
      },
    );
  }

  void _deliver(Map<String, dynamic> data) {
    if (data['method'] == 'notifications/tools/list_changed') {
      _logger.event(
        'agent.mcp.catalog_changed',
        channel: LogChannel.agent,
        fields: _logFields,
      );
      onToolsChanged?.call();
      return;
    }
    final id = data['id'];
    if (id is int) {
      final waiting = _pending[id];
      if (waiting != null && !waiting.isCompleted) waiting.complete(data);
    }
  }

  void _failPending(Object e, StackTrace s) {
    if (!_closed) {
      _logger.event(
        'agent.mcp.stream_failed',
        channel: LogChannel.agent,
        level: LogLevel.warning,
        fields: {..._logFields, ...AppLogger.errorFields(e)},
      );
    }
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(e, s);
    }
    if (!_endpoint.isCompleted && server.transport == McpTransport.sse) {
      _endpoint.completeError(e, s);
    }
  }

  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    CancelToken? cancelToken,
  }) async {
    final id = ++_sequence;
    final watch = Stopwatch()..start();
    final fields = {..._logFields, 'rpc': id, 'method': method};
    _logger.event(
      'agent.mcp.request_started',
      channel: LogChannel.agent,
      fields: fields,
    );
    try {
      final result = await _request(
        method,
        params,
        id: id,
        cancelToken: cancelToken,
      );
      _logger.event(
        'agent.mcp.request_completed',
        channel: LogChannel.agent,
        fields: {
          ...fields,
          'elapsed_ms': watch.elapsedMilliseconds,
          if (method == 'tools/call') 'tool_error': result['isError'] == true,
        },
      );
      return result;
    } catch (error) {
      _logger.event(
        'agent.mcp.request_failed',
        channel: LogChannel.agent,
        level: error is DioException && CancelToken.isCancel(error)
            ? LogLevel.info
            : LogLevel.error,
        fields: {
          ...fields,
          'elapsed_ms': watch.elapsedMilliseconds,
          ...AppLogger.errorFields(error),
        },
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    Map<String, dynamic> params, {
    required int id,
    CancelToken? cancelToken,
  }) async {
    if (_closed) throw StateError('MCP session closed');
    final body = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    };
    final token = cancelToken ?? _lifetime;
    Map<String, dynamic> response;
    if (server.transport == McpTransport.sse) {
      final waiting = Completer<Map<String, dynamic>>();
      waiting.future.ignore();
      _pending[id] = waiting;
      try {
        final endpoint = await _endpoint.future;
        await dio.post<dynamic>(
          endpoint.toString(),
          data: body,
          options: Options(headers: _headers),
          cancelToken: token,
        );
        response = await Future.any([
          waiting.future,
          token.whenCancel.then<Map<String, dynamic>>((e) => throw e),
        ]).timeout(const Duration(seconds: 30));
      } finally {
        _pending.remove(id);
      }
    } else {
      response = await _post(body, token: token);
    }
    if (response['id'] != id) {
      throw const FormatException('MCP response ID mismatch');
    }
    if (response['error'] != null) {
      final error = response['error'];
      _logger.event(
        'agent.mcp.rpc_error',
        channel: LogChannel.agent,
        level: LogLevel.error,
        fields: {
          ..._logFields,
          'rpc': id,
          'code': error is Map && error['code'] is num ? error['code'] : null,
        },
      );
      throw StateError(LogRedactor.redact(jsonEncode(response['error'])));
    }
    final result = response['result'];
    if (result is! Map<String, dynamic>) {
      throw const FormatException('Invalid MCP result');
    }
    return result;
  }

  Future<Map<String, dynamic>> _post(
    Map<String, dynamic> body, {
    required CancelToken token,
    bool notification = false,
  }) async {
    final r = await dio.post<ResponseBody>(
      uri.toString(),
      data: body,
      cancelToken: token,
      options: Options(
        headers: _headers,
        responseType: ResponseType.stream,
        validateStatus: (_) => true,
      ),
    );
    if ((r.statusCode ?? 500) >= 300) {
      _logger.event(
        'agent.mcp.http_error',
        channel: LogChannel.agent,
        level: LogLevel.error,
        fields: {..._logFields, 'rpc': body['id'], 'http_status': r.statusCode},
      );
      throw StateError('MCP HTTP ${r.statusCode}');
    }
    _sessionId = r.headers.value('Mcp-Session-Id') ?? _sessionId;
    final response = r.data;
    if (response == null || r.statusCode == 202 || r.statusCode == 204) {
      return {};
    }
    if (r.headers.value('content-type')?.contains('text/event-stream') ==
        true) {
      await for (final event in decodeServerEvents(response.stream)) {
        final message = jsonDecode(event.data) as Map<String, dynamic>;
        if (message['id'] == body['id']) return message;
        _deliver(message);
      }
      if (notification) return {};
      throw StateError('MCP response stream interrupted');
    }
    final bytes = <int>[];
    await for (final b in response.stream) {
      bytes.addAll(b);
      if (bytes.length > 1024 * 1024) {
        throw const FormatException('MCP response exceeds 1 MiB');
      }
    }
    if (bytes.isEmpty && notification) return {};
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  Future<void> notify(String method, Map<String, dynamic> params) async {
    if (_closed) return;
    final body = {'jsonrpc': '2.0', 'method': method, 'params': params};
    if (server.transport == McpTransport.sse) {
      await dio.post<dynamic>(
        (await _endpoint.future).toString(),
        data: body,
        options: Options(headers: _headers),
        cancelToken: _lifetime,
      );
    } else {
      await _post(body, token: _lifetime, notification: true);
    }
  }

  Future<List<Map<String, dynamic>>> listTools() async {
    final tools = <Map<String, dynamic>>[];
    String? cursor;
    final seen = <String>{};
    do {
      final result = await request('tools/list', {
        if (cursor != null) 'cursor': cursor,
      });
      tools.addAll(
        (result['tools'] as List? ?? []).map(
          (t) => Map<String, dynamic>.from(t),
        ),
      );
      cursor = result['nextCursor'] as String?;
      if (tools.length > 256 || cursor != null && !seen.add(cursor)) {
        throw const FormatException('MCP tool catalog limit');
      }
    } while (cursor != null);
    _logger.event(
      'agent.mcp.tools_listed',
      channel: LogChannel.agent,
      fields: {..._logFields, 'count': tools.length},
    );
    return tools;
  }

  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, dynamic> arguments,
    CancelToken token,
  ) => request('tools/call', {
    'name': name,
    'arguments': arguments,
  }, cancelToken: token);
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _lifetime.cancel('closed');
    await _subscription?.cancel();
    if (_sessionId != null && server.transport == McpTransport.streamableHttp) {
      try {
        await dio.delete<dynamic>(
          server.url,
          options: Options(
            headers: _headers,
            sendTimeout: const Duration(seconds: 2),
            receiveTimeout: const Duration(seconds: 2),
          ),
        );
      } on DioException {
        // Some MCP servers do not implement optional session deletion.
      }
    }
    _failPending(StateError('MCP session closed'), StackTrace.current);
    _pending.clear();
    dio.close(force: true);
    _logger.event(
      'agent.mcp.closed',
      channel: LogChannel.agent,
      fields: _logFields,
    );
  }
}
