import 'dart:convert';
import 'package:servllama/features/chat/models/message_part.dart';
import 'package:servllama/features/chat/models/stream_chunk.dart';

/// One generation's ordered snapshots. Every stream and tool update addresses
/// a stable part ID; text, arguments and results share the revision body.
class StreamChunkHandler {
  final _parts = <MessagePart>[];
  List<MessagePart> get parts => List.unmodifiable(_parts);
  String get content => messageText(_parts);
  String get reasoning => messageReasoning(_parts) ?? '';

  void updateTool(ToolPart part) {
    final index = _parts.indexWhere((p) => p.id == part.id);
    if (index < 0) {
      _parts.add(part);
    } else {
      _parts[index] = part;
    }
  }

  void appendText(String text, {String id = 'error'}) {
    if (text.isEmpty) return;
    finish();
    final last = _parts.lastOrNull;
    if (last is TextPart && last.id == id) {
      _parts[_parts.length - 1] = TextPart(id, last.text + text);
    } else {
      _parts.add(TextPart(id, text));
    }
  }

  void finish({DateTime? at, bool stopped = false}) {
    final now = at ?? DateTime.now().toUtc();
    for (var i = 0; i < _parts.length; i++) {
      final p = _parts[i];
      if (p is ReasoningPart && p.finishedAt == null) {
        _parts[i] = p.copyWith(finishedAt: now);
      } else if (stopped &&
          p is ToolPart &&
          (p.state == ToolState.streaming || p.state == ToolState.ready)) {
        _parts[i] = p.copyWith(state: ToolState.cancelled);
      }
    }
  }

  bool handle(StreamChunk chunk) {
    switch (chunk) {
      case TextStart():
        finish();
      case TextDelta(:final id, :final text):
        if (text.isEmpty) return false;
        appendText(text, id: id);
      case ReasoningStart(:final id):
        finish();
        _parts.add(ReasoningPart(id, '', startedAt: DateTime.now().toUtc()));
      case ReasoningDelta(:final id, :final text):
        if (text.isEmpty) return false;
        final index = _parts.indexWhere(
          (p) => p is ReasoningPart && p.id == id,
        );
        if (index < 0) {
          _parts.add(
            ReasoningPart(id, text, startedAt: DateTime.now().toUtc()),
          );
        } else {
          final p = _parts[index] as ReasoningPart;
          _parts[index] = p.copyWith(text: p.text + text);
        }
      case ReasoningEnd(:final id):
        final index = _parts.indexWhere(
          (p) => p is ReasoningPart && p.id == id,
        );
        if (index >= 0) {
          _parts[index] = (_parts[index] as ReasoningPart).copyWith(
            finishedAt: DateTime.now().toUtc(),
          );
        }
      case ToolCallStart(:final id, :final callId, :final toolName):
        if (_parts.any((p) => p.id == id)) {
          throw const FormatException('Repeated tool start');
        }
        finish();
        _parts.add(ToolPart(id: id, callId: callId, name: toolName));
      case ToolCallDelta(
        :final id,
        :final callId,
        :final toolNameDelta,
        :final inputDelta,
      ):
        final index = _parts.indexWhere((p) => p is ToolPart && p.id == id);
        if (index < 0 || (_parts[index] as ToolPart).inputComplete) {
          throw const FormatException('Invalid tool delta');
        }
        final p = _parts[index] as ToolPart;
        if (p.input.length + inputDelta.length > 128 * 1024) {
          throw const FormatException('Tool arguments exceed limit');
        }
        _parts[index] = p.copyWith(
          callId: callId,
          name: p.name + toolNameDelta,
          input: p.input + inputDelta,
        );
      case ToolCallEnd(:final id, :final call):
        final index = _parts.indexWhere((p) => p is ToolPart && p.id == id);
        if (index < 0 || (_parts[index] as ToolPart).inputComplete) {
          throw const FormatException('Invalid tool end');
        }
        _parts[index] = (_parts[index] as ToolPart).copyWith(
          callId: call.id,
          name: call.name,
          inputComplete: true,
          input: jsonEncode(call.arguments),
          state: ToolState.ready,
        );
      case Finish() || AssistantRoundEnd():
        finish();
      case TextEnd() || ToolCallResult() || Usage():
        return false;
    }
    return true;
  }
}
