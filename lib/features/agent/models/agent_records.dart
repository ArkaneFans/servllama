import 'package:servllama/features/chat/models/message_part.dart';

enum McpTransport { streamableHttp, sse }

/// Validated HTTP headers shared by server settings and MCP requests.
class McpCredentials {
  McpCredentials({Map<String, String> headers = const {}})
    : headers = Map.unmodifiable(headers);

  final Map<String, String> headers;

  void validate() {
    if (headers.length > 16) {
      throw const FormatException('Invalid MCP headers');
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
          }.contains(name)) {
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
    this.enabled = true,
    this.transport = McpTransport.streamableHttp,
    this.headers = const {},
    this.revision = 1,
    this.tools = const [],
  });
  final String id, name, url;
  final bool enabled;
  final McpTransport transport;
  final Map<String, String> headers;
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
    'enabled': enabled,
    'transport': transport.name,
    'headers': headers,
    'revision': revision,
    'tools': tools,
  };
  factory McpServer.fromJson(Map<String, dynamic> j) => McpServer(
    id: j['id'],
    name: j['name'],
    url: j['url'],
    enabled: j['enabled'] as bool? ?? true,
    transport: McpTransport.values.byName(j['transport'] ?? 'streamableHttp'),
    headers: Map.unmodifiable(
      Map<String, String>.from(j['headers'] ?? const {}),
    ),
    revision: j['revision'] ?? 1,
    tools: (j['tools'] as List? ?? [])
        .map((v) => Map<String, dynamic>.from(v))
        .toList(),
  );
}

enum SkillSource { unknown, paste, file }

enum SkillFormatError { missingName, missingDescription, invalidMetadata }

class SkillFormatException extends FormatException {
  const SkillFormatException(this.error, String message) : super(message);

  final SkillFormatError error;
}

class SkillRecord {
  const SkillRecord({
    required this.id,
    required this.name,
    required this.path,
    required this.hash,
    required this.description,
    this.hasScripts = false,
    this.enabled = true,
    this.source = SkillSource.unknown,
    this.installedAt,
    this.updatedAt,
  });
  final String id, name, path, hash, description;
  final bool hasScripts;
  final bool enabled;
  final SkillSource source;
  final DateTime? installedAt, updatedAt;

  bool get hasValidMetadata =>
      name.trim().isNotEmpty && description.trim().isNotEmpty;

  SkillRecord copyWith({
    String? name,
    String? path,
    String? hash,
    String? description,
    bool? hasScripts,
    bool? enabled,
    SkillSource? source,
    DateTime? installedAt,
    DateTime? updatedAt,
  }) => SkillRecord(
    id: id,
    name: name ?? this.name,
    path: path ?? this.path,
    hash: hash ?? this.hash,
    description: description ?? this.description,
    hasScripts: hasScripts ?? this.hasScripts,
    enabled: enabled ?? this.enabled,
    source: source ?? this.source,
    installedAt: installedAt ?? this.installedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'path': path,
    'hash': hash,
    'description': description,
    'hasScripts': hasScripts,
    'enabled': enabled,
    'source': source.name,
    'installedAt': installedAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
  factory SkillRecord.fromJson(Map<String, dynamic> j) => SkillRecord(
    id: j['id'],
    name: j['name'],
    path: j['path'],
    hash: j['hash'],
    description: j['description'],
    hasScripts: j['hasScripts'] ?? false,
    enabled: j['enabled'] as bool? ?? true,
    source: _skillSource(j['source']),
    installedAt: _skillDate(j['installedAt']),
    updatedAt: _skillDate(j['updatedAt']),
  );

  static SkillSource _skillSource(Object? value) {
    for (final source in SkillSource.values) {
      if (source.name == value) return source;
    }
    return SkillSource.unknown;
  }

  static DateTime? _skillDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class SkillFileEntry {
  const SkillFileEntry({
    required this.relativePath,
    required this.size,
    required this.isText,
  });

  final String relativePath;
  final int size;
  final bool isText;
}

class SkillDetails {
  const SkillDetails({required this.record, required this.files});

  final SkillRecord record;
  final List<SkillFileEntry> files;

  int get totalBytes => files.fold(0, (total, file) => total + file.size);
}

/// A scoped projection of a revision's ToolPart for approvals/history pages.
/// The message revision is the only persisted execution record.
class ToolActivity {
  const ToolActivity({
    required this.runId,
    required this.conversationId,
    required this.revisionId,
    required this.part,
  });
  final String runId, conversationId, revisionId;
  final ToolPart part;
  String get id => '$runId:${part.callId ?? part.id}';
  String get callId => part.callId ?? '';
  String get name => part.name;
  String get state => part.state.name;
  Map<String, dynamic> get payload => part.payload;
}
