import 'dart:convert';

enum ChatTimelineKind { text, reasoning, tool }

/// Revision-owned ordering metadata. Text remains in the revision's two bodies;
/// tool arguments/results remain in tool_invocations, addressed by Run + call ID.
class ChatTimelinePart {
  const ChatTimelinePart({
    required this.kind,
    this.start = 0,
    this.end = 0,
    this.callId,
    this.toolName,
    this.startedAt,
    this.finishedAt,
  });

  final ChatTimelineKind kind;
  final int start, end;
  final String? callId, toolName;
  final DateTime? startedAt, finishedAt;

  ChatTimelinePart extend(int end, {DateTime? finishedAt}) => ChatTimelinePart(
    kind: kind,
    start: start,
    end: end,
    callId: callId,
    toolName: toolName,
    startedAt: startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    if (kind != ChatTimelineKind.tool) ...{'start': start, 'end': end},
    if (callId != null) 'callId': callId,
    if (toolName != null) 'toolName': toolName,
    if (startedAt != null) 'startedAt': startedAt!.millisecondsSinceEpoch,
    if (finishedAt != null) 'finishedAt': finishedAt!.millisecondsSinceEpoch,
  };

  static List<ChatTimelinePart> decode(String source) {
    try {
      final value = jsonDecode(source);
      if (value is! List) return const [];
      final result = <ChatTimelinePart>[];
      for (final raw in value) {
        if (raw is! Map) return const [];
        final kind = ChatTimelineKind.values.byName(raw['kind'] as String);
        final start = raw['start'] as int? ?? 0;
        final end = raw['end'] as int? ?? 0;
        final call = raw['callId'] as String?;
        if (start < 0 ||
            end < start ||
            (kind == ChatTimelineKind.tool && (call == null || call.isEmpty))) {
          return const [];
        }
        DateTime? date(String key) => raw[key] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(raw[key] as int, isUtc: true);
        result.add(
          ChatTimelinePart(
            kind: kind,
            start: start,
            end: end,
            callId: call,
            toolName: raw['toolName'] as String?,
            startedAt: date('startedAt'),
            finishedAt: date('finishedAt'),
          ),
        );
      }
      return List.unmodifiable(result);
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    } on ArgumentError {
      return const [];
    }
  }

  static String encode(List<ChatTimelinePart> parts) =>
      jsonEncode(parts.map((p) => p.toJson()).toList());
}

/// One builder per generation; tokens extend the current range, never create
/// one node per token. A model-round boundary closes the current reasoning step.
class ChatTimelineBuilder {
  final _parts = <ChatTimelinePart>[];
  int _textEnd = 0, _reasoningEnd = 0;
  List<ChatTimelinePart> get snapshot => List.unmodifiable(_parts);

  void append({String text = '', String reasoning = '', DateTime? at}) {
    // A delta carrying both channels has no finer ordering information.
    // Reasoning precedes text, consistently with the protocol's display order.
    final now = at ?? DateTime.now().toUtc();
    if (reasoning.isNotEmpty) {
      _append(
        ChatTimelineKind.reasoning,
        _reasoningEnd,
        _reasoningEnd + reasoning.length,
        now,
      );
      _reasoningEnd += reasoning.length;
    }
    if (text.isNotEmpty) {
      finish(at: now);
      _append(ChatTimelineKind.text, _textEnd, _textEnd + text.length, now);
      _textEnd += text.length;
    }
  }

  void _append(ChatTimelineKind kind, int start, int end, DateTime at) {
    final last = _parts.lastOrNull;
    if (last?.kind == kind &&
        (kind == ChatTimelineKind.text || last!.finishedAt == null)) {
      _parts[_parts.length - 1] = last!.extend(end);
    } else {
      _parts.add(
        ChatTimelinePart(
          kind: kind,
          start: start,
          end: end,
          startedAt: kind == ChatTimelineKind.reasoning ? at : null,
        ),
      );
    }
  }

  void tool(String callId, String name) {
    finish();
    _parts.add(
      ChatTimelinePart(
        kind: ChatTimelineKind.tool,
        callId: callId,
        toolName: name,
      ),
    );
  }

  void finish({DateTime? at}) {
    final last = _parts.lastOrNull;
    if (last?.kind == ChatTimelineKind.reasoning && last!.finishedAt == null) {
      _parts[_parts.length - 1] = last.extend(
        last.end,
        finishedAt: at ?? DateTime.now().toUtc(),
      );
    }
  }
}
