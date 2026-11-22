import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/chat/models/stream_chunk.dart';

/// Normalize protocols without explicit text boundaries into ID-based series.
/// Explicit block protocols may use block IDs directly instead.
class StreamChunkEmitter {
  StreamChunkEmitter() : scope = newId();
  final String scope;
  int _sequence = 0;
  String? _textId, _reasoningId;

  String nextId(String kind) => '$scope:$kind:${_sequence++}';

  Iterable<StreamChunk> text(String value) sync* {
    if (value.isEmpty) return;
    yield* closeReasoning();
    if (_textId == null) {
      _textId = nextId('text');
      yield TextStart(_textId!);
    }
    yield TextDelta(id: _textId!, text: value);
  }

  Iterable<StreamChunk> reasoning(String value) sync* {
    if (value.isEmpty) return;
    yield* closeText();
    if (_reasoningId == null) {
      _reasoningId = nextId('reasoning');
      yield ReasoningStart(_reasoningId!);
    }
    yield ReasoningDelta(id: _reasoningId!, text: value);
  }

  Iterable<StreamChunk> closeText() sync* {
    if (_textId case final id?) {
      _textId = null;
      yield TextEnd(id);
    }
  }

  Iterable<StreamChunk> closeReasoning() sync* {
    if (_reasoningId case final id?) {
      _reasoningId = null;
      yield ReasoningEnd(id);
    }
  }

  Iterable<StreamChunk> close() sync* {
    yield* closeText();
    yield* closeReasoning();
  }
}
