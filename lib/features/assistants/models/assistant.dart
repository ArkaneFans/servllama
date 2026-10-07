import 'package:servllama/features/agent/models/web_search.dart';

enum AiProtocol { openai, anthropic, gemini }

class ChatTarget {
  const ChatTarget.local(this.assetId) : connectionId = null, modelId = null;
  const ChatTarget.remote(this.connectionId, this.modelId) : assetId = null;
  final String? assetId, connectionId, modelId;
  bool get isRemote => connectionId != null;
  bool get isConfigured => isRemote
      ? connectionId!.isNotEmpty && (modelId?.trim().isNotEmpty ?? false)
      : assetId?.isNotEmpty == true;
  @override
  bool operator ==(Object other) =>
      other is ChatTarget &&
      assetId == other.assetId &&
      connectionId == other.connectionId &&
      modelId == other.modelId;
  @override
  int get hashCode => Object.hash(assetId, connectionId, modelId);
  Map<String, dynamic> toJson() => {
    'assetId': assetId,
    'connectionId': connectionId,
    'modelId': modelId,
  };
  factory ChatTarget.fromJson(Map<String, dynamic> j) =>
      j['connectionId'] != null
      ? ChatTarget.remote(j['connectionId'], j['modelId'])
      : ChatTarget.local(j['assetId']);
}

class Assistant {
  const Assistant({
    required this.id,
    required this.name,
    this.avatar = '',
    this.revision = 1,
    this.instructions = '',
    this.chatTarget,
    this.temperature = .7,
    this.maxTokens = 2048,
    this.contextChars = 24000,
    this.maxTurns = 8,
    this.maxToolCalls = 16,
    this.timeoutSeconds = 180,
    this.tools = const [],
    this.skillIds = const [],
    this.mcpServerIds = const [],
    this.webSearch = const WebSearchOptions(),
  });
  final String id, name, avatar, instructions;
  final int revision,
      maxTokens,
      contextChars,
      maxTurns,
      maxToolCalls,
      timeoutSeconds;
  final double temperature;
  final ChatTarget? chatTarget;
  final List<String> tools, skillIds, mcpServerIds;
  final WebSearchOptions webSearch;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'revision': revision,
    'instructions': instructions,
    'chatTarget': chatTarget?.toJson(),
    'temperature': temperature,
    'maxTokens': maxTokens,
    'contextChars': contextChars,
    'maxTurns': maxTurns,
    'maxToolCalls': maxToolCalls,
    'timeoutSeconds': timeoutSeconds,
    'tools': tools,
    'skillIds': skillIds,
    'mcpServerIds': mcpServerIds,
    'webSearch': webSearch.toJson(),
  };
  factory Assistant.fromJson(Map<String, dynamic> j) => Assistant(
    id: j['id'],
    name: j['name'],
    avatar: j['avatar'] ?? '',
    revision: j['revision'] ?? 1,
    instructions: j['instructions'] ?? '',
    chatTarget: _readChatTarget(j),
    temperature: (j['temperature'] as num? ?? .7).toDouble(),
    maxTokens: j['maxTokens'] ?? 2048,
    contextChars: j['contextChars'] ?? 24000,
    maxTurns: j['maxTurns'] ?? 8,
    maxToolCalls: j['maxToolCalls'] ?? 16,
    timeoutSeconds: j['timeoutSeconds'] ?? 180,
    tools: List<String>.unmodifiable(j['tools'] ?? []),
    skillIds: List<String>.unmodifiable(j['skillIds'] ?? []),
    mcpServerIds: List<String>.unmodifiable(j['mcpServerIds'] ?? []),
    webSearch: WebSearchOptions.fromJson(
      Map<String, dynamic>.from(j['webSearch'] ?? {}),
    ),
  );
  static ChatTarget? _readChatTarget(Map<String, dynamic> json) {
    final raw = json.containsKey('chatTarget')
        ? json['chatTarget']
        : json.containsKey('defaultTarget')
        ? json['defaultTarget']
        : json['target'];
    if (raw == null) return null;
    final target = ChatTarget.fromJson(Map<String, dynamic>.from(raw));
    return !target.isRemote && target.assetId == null ? null : target;
  }

  Assistant changed(Map<String, dynamic> changes) =>
      Assistant.fromJson({...toJson(), ...changes});
}

class ModelCapabilities {
  static const textOnly = ModelCapabilities(
    supportsImages: false,
    supportsTools: false,
  );
  const ModelCapabilities({
    this.supportsImages = true,
    this.supportsTools = true,
  });
  final bool supportsImages, supportsTools;
  Map<String, dynamic> toJson() => {
    'supportsImages': supportsImages,
    'supportsTools': supportsTools,
  };
  factory ModelCapabilities.fromJson(Map<String, dynamic> json) =>
      ModelCapabilities(
        supportsImages: json['supportsImages'] ?? true,
        supportsTools: json['supportsTools'] ?? true,
      );
}

class AiConnection {
  const AiConnection({
    required this.id,
    required this.name,
    required this.protocol,
    required this.baseUrl,
    this.secretRef,
    this.models = const [],
    this.revision = 1,
    this.modelCapabilities = const {},
    this.enabled = true,
  });
  final String id, name, baseUrl;
  final String? secretRef;
  final AiProtocol protocol;
  final List<String> models;
  final int revision;
  final bool enabled;
  final Map<String, ModelCapabilities> modelCapabilities;
  ModelCapabilities capabilitiesFor(String id) =>
      modelCapabilities[id] ?? const ModelCapabilities();
  bool hasModel(String? id) => enabled && models.contains(id);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'protocol': protocol.name,
    'baseUrl': baseUrl,
    'secretRef': secretRef,
    'models': models,
    'revision': revision,
    'modelCapabilities': {
      for (final model in models) model: capabilitiesFor(model).toJson(),
    },
    'enabled': enabled,
  };
  factory AiConnection.fromJson(Map<String, dynamic> j) => AiConnection(
    id: j['id'],
    name: j['name'],
    protocol: AiProtocol.values.byName(j['protocol']),
    baseUrl: j['baseUrl'],
    secretRef: j['secretRef'],
    models: List<String>.unmodifiable(j['models'] ?? []),
    revision: j['revision'] ?? 1,
    modelCapabilities: Map.unmodifiable({
      for (final model in List<String>.from(j['models'] ?? []))
        model: ModelCapabilities.fromJson(
          Map<String, dynamic>.from(
            (j['modelCapabilities'] as Map?)?[model] ??
                // Read old provider-wide settings for its existing models only.
                // New writes contain model settings and drop the retired flags.
                (j.containsKey('modelCapabilities') ? <String, dynamic>{} : j),
          ),
        ),
    }),
    enabled: j['enabled'] ?? true,
  );
  AiConnection changed(Map<String, dynamic> changes) =>
      AiConnection.fromJson({...toJson(), ...changes});
  void validate() {
    final uri = Uri.tryParse(baseUrl);
    if (name.trim().isEmpty ||
        uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Invalid connection name or base URL');
    }
    if (models.any((id) => id.trim().isEmpty || id.length > 512)) {
      throw const FormatException('Invalid model ID');
    }
  }
}

class UserProfile {
  const UserProfile({
    this.name = '',
    this.avatar = '🙂',
    this.description = '',
  });
  final String name, avatar, description;
  Map<String, dynamic> toJson() => {
    'name': name,
    'avatar': avatar,
    'description': description,
  };
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    name: j['name'] ?? '',
    avatar: j['avatar'] ?? '🙂',
    description: j['description'] ?? j['preferences'] ?? '',
  );
}
