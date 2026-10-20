class AiImage {
  const AiImage(this.mime, this.base64);
  final String mime, base64;
}

class AiToolCall {
  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.providerState = const {},
  });
  final String id, name;
  final Map<String, dynamic> arguments, providerState;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'arguments': arguments,
    'providerState': providerState,
  };
  factory AiToolCall.fromJson(Map<String, dynamic> value) => AiToolCall(
    id: value['id'],
    name: value['name'],
    arguments: Map<String, dynamic>.from(value['arguments']),
    providerState: Map<String, dynamic>.from(value['providerState'] ?? {}),
  );
}

class AiTurn {
  const AiTurn({
    required this.role,
    this.text = '',
    this.images = const [],
    this.calls = const [],
    this.toolCallId,
    this.toolName,
    this.isError = false,
    this.providerParts = const [],
  });
  final String role, text;
  final List<AiImage> images;
  final List<AiToolCall> calls;
  final String? toolCallId, toolName;
  final bool isError;
  final List<Map<String, dynamic>> providerParts;
  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    'calls': calls.map((c) => c.toJson()).toList(),
    'toolCallId': toolCallId,
    'toolName': toolName,
    'isError': isError,
    'providerParts': providerParts,
  };
  factory AiTurn.fromJson(Map<String, dynamic> value) => AiTurn(
    role: value['role'],
    text: value['text'] ?? '',
    calls: (value['calls'] as List? ?? [])
        .map((c) => AiToolCall.fromJson(Map<String, dynamic>.from(c)))
        .toList(),
    toolCallId: value['toolCallId'],
    toolName: value['toolName'],
    isError: value['isError'] == true,
    providerParts: (value['providerParts'] as List? ?? [])
        .map((p) => Map<String, dynamic>.from(p))
        .toList(),
  );
}

class AiTool {
  const AiTool(this.name, this.description, this.schema);
  final String name, description;
  final Map<String, dynamic> schema;
}

class AiEvent {
  const AiEvent({
    this.text = '',
    this.reasoning = '',
    this.calls = const [],
    this.providerParts = const [],
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.stopReason,
  });
  final String text, reasoning;
  final List<AiToolCall> calls;
  final List<Map<String, dynamic>> providerParts;
  final int inputTokens, outputTokens;
  final String? stopReason;
}
