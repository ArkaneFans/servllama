import 'dart:convert';

/// The ordered, revision-owned message body. Presentation blocks are derived
/// from these values; streaming and tool execution update the same tool slot.
enum MessagePartKind { text, reasoning, tool }

sealed class MessagePart {
  const MessagePart(this.id);
  final String id;
  MessagePartKind get kind => switch (this) {
    TextPart() => MessagePartKind.text,
    ReasoningPart() => MessagePartKind.reasoning,
    ToolPart() => MessagePartKind.tool,
  };
  Map<String, dynamic> toJson();

  static String encode(List<MessagePart> parts) =>
      jsonEncode(parts.map((p) => p.toJson()).toList());

  static List<MessagePart> decode(String source) => List.unmodifiable(
    (jsonDecode(source) as List).map((raw) {
      final j = Map<String, dynamic>.from(raw as Map);
      return switch (j['kind']) {
        'text' => TextPart(j['id'], j['text']),
        'reasoning' => ReasoningPart(
          j['id'],
          j['text'],
          startedAt: _date(j['startedAt']),
          finishedAt: _date(j['finishedAt']),
        ),
        'tool' => ToolPart.fromJson(j),
        _ => throw const FormatException('Unknown message part'),
      };
    }),
  );

  static DateTime? _date(Object? value) => value == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);
}

class TextPart extends MessagePart {
  const TextPart(super.id, this.text);
  final String text;
  @override
  Map<String, dynamic> toJson() => {'kind': 'text', 'id': id, 'text': text};
}

class ReasoningPart extends MessagePart {
  const ReasoningPart(super.id, this.text, {this.startedAt, this.finishedAt});
  final String text;
  final DateTime? startedAt, finishedAt;
  ReasoningPart copyWith({String? text, DateTime? finishedAt}) => ReasoningPart(
    id,
    text ?? this.text,
    startedAt: startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
  );
  @override
  Map<String, dynamic> toJson() => {
    'kind': 'reasoning',
    'id': id,
    'text': text,
    if (startedAt != null) 'startedAt': startedAt!.millisecondsSinceEpoch,
    if (finishedAt != null) 'finishedAt': finishedAt!.millisecondsSinceEpoch,
  };
}

enum ToolState {
  streaming,
  ready,
  prepared,
  pendingApproval,
  approved,
  executing,
  succeeded,
  failed,
  rejected,
  cancelled,
  unknownOutcome,
}

class ToolPart extends MessagePart {
  const ToolPart({
    required String id,
    this.callId,
    this.name = '',
    this.input = '',
    this.inputComplete = false,
    this.state = ToolState.streaming,
    this.result,
    this.error,
    this.resultTruncated = false,
    this.startedAt,
    this.finishedAt,
    this.durationMs,
    this.metadata = const {},
  }) : super(id);

  final String? callId;
  final String name, input;
  final bool inputComplete, resultTruncated;
  final ToolState state;

  /// Parsed complete input is a derived view, never a second stored body.
  Map<String, dynamic>? get arguments => !inputComplete || input.isEmpty
      ? null
      : Map<String, dynamic>.unmodifiable(jsonDecode(input) as Map);
  final String? result, error;
  final DateTime? startedAt, finishedAt;
  final int? durationMs;

  /// Authorization snapshot, display hints and tool-specific result metadata.
  final Map<String, dynamic> metadata;
  bool get inputIsMutable =>
      state == ToolState.streaming || state == ToolState.ready;
  bool get needsAttention => const {
    ToolState.streaming,
    ToolState.ready,
    ToolState.prepared,
    ToolState.pendingApproval,
    ToolState.approved,
    ToolState.executing,
    ToolState.unknownOutcome,
  }.contains(state);

  ToolPart copyWith({
    String? callId,
    String? name,
    String? input,
    bool? inputComplete,
    ToolState? state,
    String? result,
    String? error,
    bool? resultTruncated,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? durationMs,
    Map<String, dynamic>? metadata,
  }) => ToolPart(
    id: id,
    callId: callId ?? this.callId,
    name: name ?? this.name,
    input: input ?? this.input,
    inputComplete: inputComplete ?? this.inputComplete,
    state: state ?? this.state,
    result: result ?? this.result,
    error: error ?? this.error,
    resultTruncated: resultTruncated ?? this.resultTruncated,
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
    durationMs: durationMs ?? this.durationMs,
    metadata: metadata ?? this.metadata,
  );

  /// Tool-specific view of typed lifecycle/result fields for the execution
  /// service and shared detail widgets.
  Map<String, dynamic> get payload => {
    ...metadata,
    if (inputComplete) 'arguments': arguments,
    if (result != null) 'result': result,
    if (error != null) 'error': error,
    if (resultTruncated) 'resultTruncated': true,
    if (startedAt != null) 'startedAt': startedAt!.millisecondsSinceEpoch,
    if (finishedAt != null) 'finishedAt': finishedAt!.millisecondsSinceEpoch,
    if (durationMs != null) 'durationMs': durationMs,
  };

  ToolPart withExecution(String state, Map<String, dynamic> payload) {
    final metadata = Map<String, dynamic>.from(payload);
    for (final key in const [
      'arguments',
      'result',
      'error',
      'resultTruncated',
      'startedAt',
      'finishedAt',
      'durationMs',
    ]) {
      metadata.remove(key);
    }
    return copyWith(
      state: ToolState.values.byName(state),
      result: payload['result'] as String?,
      error: payload['error'] as String?,
      resultTruncated: payload['resultTruncated'] as bool? ?? false,
      startedAt: MessagePart._date(payload['startedAt']),
      finishedAt: MessagePart._date(payload['finishedAt']),
      durationMs: payload['durationMs'] as int?,
      metadata: Map.unmodifiable(metadata),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'kind': 'tool',
    'id': id,
    if (callId != null) 'callId': callId,
    'name': name,
    'input': input,
    'inputComplete': inputComplete,
    'state': state.name,
    if (result != null) 'result': result,
    if (error != null) 'error': error,
    if (resultTruncated) 'resultTruncated': true,
    if (startedAt != null) 'startedAt': startedAt!.millisecondsSinceEpoch,
    if (finishedAt != null) 'finishedAt': finishedAt!.millisecondsSinceEpoch,
    if (durationMs != null) 'durationMs': durationMs,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };
  factory ToolPart.fromJson(Map<String, dynamic> j) => ToolPart(
    id: j['id'],
    callId: j['callId'],
    name: j['name'],
    input: j['input'] ?? '',
    inputComplete: j['inputComplete'] ?? false,
    state: ToolState.values.byName(j['state']),
    result: j['result'],
    error: j['error'],
    resultTruncated: j['resultTruncated'] ?? false,
    startedAt: MessagePart._date(j['startedAt']),
    finishedAt: MessagePart._date(j['finishedAt']),
    durationMs: j['durationMs'],
    metadata: Map.unmodifiable(Map<String, dynamic>.from(j['metadata'] ?? {})),
  );
}

/// Builds a plain message body for text constructors, edits and Hive import.
List<MessagePart> messagePartsFromText({
  String content = '',
  String? reasoning,
}) => List.unmodifiable([
  if (reasoning?.isNotEmpty == true) ReasoningPart('reasoning', reasoning!),
  if (content.isNotEmpty) TextPart('text', content),
]);

String messageText(Iterable<MessagePart> parts) =>
    parts.whereType<TextPart>().map((p) => p.text).join();
String? messageReasoning(Iterable<MessagePart> parts) {
  final reasoning = parts.whereType<ReasoningPart>().map((p) => p.text).join();
  return reasoning.isEmpty ? null : reasoning;
}

/// Checkpoints own streaming updates; the execution owner owns scheduled or settled tool
/// states. Merge inside the SQL transaction so delayed snapshots cannot erase
/// an approval, result or unknown outcome written by that owner.
List<MessagePart> mergeToolExecution(
  List<MessagePart> incoming,
  List<MessagePart> saved,
) {
  final tools = {for (final p in saved.whereType<ToolPart>()) p.id: p};
  final result = <MessagePart>[
    for (final p in incoming)
      if (p is ToolPart &&
          (tools[p.id] != null && !tools[p.id]!.inputIsMutable))
        tools[p.id]!
      else
        p,
  ];
  final ids = result.map((p) => p.id).toSet();
  result.addAll(
    tools.values.where((p) => !p.inputIsMutable && !ids.contains(p.id)),
  );
  return List.unmodifiable(result);
}
