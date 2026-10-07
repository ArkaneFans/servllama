import 'dart:convert';
import 'package:drift/drift.dart';

enum McpTransport { streamableHttp, sse }

/// The complete credential is one secure-storage value, never server config.
class McpCredentials {
  McpCredentials({this.token = '', Map<String, String> headers = const {}})
    : headers = Map.unmodifiable(headers);
  final String token;
  final Map<String, String> headers;
  static const _prefix = 'servllama-mcp-v1:';
  factory McpCredentials.fromStored(String value) {
    if (!value.startsWith(_prefix)) return McpCredentials(token: value);
    final json = jsonDecode(value.substring(_prefix.length)) as Map;
    return McpCredentials(
      token: json['token'] as String? ?? '',
      headers: Map<String, String>.from(json['headers'] as Map? ?? {}),
    );
  }
  String encode() => _prefix + jsonEncode({'token': token, 'headers': headers});
  static Map<String, String> parseHeaders(String value) {
    final parsed = jsonDecode(value);
    if (parsed is! Map ||
        parsed.keys.any((k) => k is! String) ||
        parsed.values.any((v) => v is! String)) {
      throw const FormatException(
        'HTTP headers must be a JSON object of strings',
      );
    }
    return Map<String, String>.from(parsed);
  }

  void validate() {
    if (token.length > 8192 ||
        token.contains(RegExp(r'[\r\n]')) ||
        headers.length > 16) {
      throw const FormatException('Invalid MCP credentials');
    }
    final names = <String>{};
    var size = 0;
    for (final entry in headers.entries) {
      final name = entry.key.toLowerCase();
      size += entry.key.length + entry.value.length;
      if (!RegExp(r'^[A-Za-z0-9!#$%&\x27*+.^_\x60|~-]+$').hasMatch(entry.key) ||
          !names.add(name) ||
          size > 16384 ||
          entry.value.contains(RegExp(r'[\r\n\x00]')) ||
          const {
            'host',
            'content-length',
            'content-type',
            'accept',
            'connection',
            'transfer-encoding',
            'mcp-session-id',
            'mcp-protocol-version',
          }.contains(name) ||
          (name == 'authorization' && token.isNotEmpty)) {
        throw const FormatException(
          'Invalid, duplicate or protocol-owned MCP header',
        );
      }
    }
  }
}

class McpServer {
  const McpServer({
    required this.id,
    required this.name,
    required this.url,
    this.transport = McpTransport.streamableHttp,
    this.secretRef,
    this.revision = 1,
    this.tools = const [],
  });
  final String id, name, url;
  final McpTransport transport;
  final String? secretRef;
  final int revision;
  final List<Map<String, dynamic>> tools;
  static String toolPrefix(String id) =>
      'mcp_${id.replaceAll('-', '').substring(0, 8)}_';
  void validate() {
    final endpoint = Uri.tryParse(url);
    if (name.trim().isEmpty ||
        name.length > 120 ||
        url.length > 4096 ||
        endpoint == null ||
        !['http', 'https'].contains(endpoint.scheme) ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasFragment) {
      throw const FormatException('Invalid MCP name or endpoint');
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'transport': transport.name,
    'secretRef': secretRef,
    'revision': revision,
    'tools': tools,
  };
  factory McpServer.fromJson(Map<String, dynamic> j) => McpServer(
    id: j['id'],
    name: j['name'],
    url: j['url'],
    transport: McpTransport.values.byName(j['transport'] ?? 'streamableHttp'),
    secretRef: j['secretRef'],
    revision: j['revision'] ?? 1,
    tools: (j['tools'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v))
        .toList(),
  );
}

class SkillRecord {
  const SkillRecord({
    required this.id,
    required this.name,
    required this.path,
    required this.hash,
    required this.description,
    this.hasScripts = false,
  });
  final String id, name, path, hash, description;
  final bool hasScripts;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'hash': hash,
    'description': description,
    'hasScripts': hasScripts,
  };
  factory SkillRecord.fromJson(Map<String, dynamic> j) => SkillRecord(
    id: j['id'],
    name: j['name'],
    path: j['path'],
    hash: j['hash'],
    description: j['description'],
    hasScripts: j['hasScripts'] ?? false,
  );
}

class ToolInvocation {
  const ToolInvocation({
    required this.id,
    required this.runId,
    required this.callId,
    required this.conversationId,
    required this.name,
    required this.state,
    required this.payload,
  });
  final String id, runId, callId, conversationId, name, state;
  final Map<String, dynamic> payload;
  factory ToolInvocation.fromRow(QueryRow r) => ToolInvocation(
    id: r.read('id'),
    runId: r.read('run_id'),
    callId: r.read('call_id'),
    conversationId: r.read('conversation_id'),
    name: r.read('name'),
    state: r.read('state'),
    payload: jsonDecode(r.read<String>('payload')),
  );
}
