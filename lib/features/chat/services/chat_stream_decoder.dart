import 'dart:convert';

import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/chat/models/ai_turn.dart';
import 'package:servllama/features/chat/models/stream_chunk.dart';
import 'package:servllama/features/chat/services/stream_chunk_emitter.dart';

/// One HTTP response. Wire fragments are exposed immediately; validated calls
/// and Finish remain distinct from permission to execute. Never logs payloads.
class ChatStreamDecoder {
  ChatStreamDecoder(this.protocol);
  final AiProtocol protocol;
  final _emitter = StreamChunkEmitter();
  final _calls = <int, _CallBuffer>{};
  final _parts = <int, Map<String, dynamic>>{};
  final _ended = <int>{};
  final _callIds = <String>{};
  final _closedBlocks = <int>{};
  int _input = 0, _output = 0;
  String? _finish;

  String _blockId(int index) => '${_emitter.scope}:block:$index';

  List<StreamChunk> accept(Map<String, dynamic> data) {
    final chunks = <StreamChunk>[];
    switch (protocol) {
      case AiProtocol.openai:
        final usage = data['usage'] as Map?;
        if (usage != null) {
          _input = (usage['prompt_tokens'] as int?) ?? _input;
          _output = (usage['completion_tokens'] as int?) ?? _output;
          chunks.add(Usage(inputTokens: _input, outputTokens: _output));
        }
        for (final choice
            in (data['choices'] as List? ?? []).whereType<Map>().take(1)) {
          _finish = choice['finish_reason'] as String? ?? _finish;
          final delta = choice['delta'] as Map? ?? {};
          // A packet with both channels does not encode their relative order.
          chunks.addAll(
            _emitter.reasoning(delta['reasoning_content'] as String? ?? ''),
          );
          chunks.addAll(_emitter.text(delta['content'] as String? ?? ''));
          for (final tool
              in (delta['tool_calls'] as List? ?? []).whereType<Map>()) {
            chunks.addAll(_emitter.close());
            final rawId = tool['id'] as String?;
            final vendorId = rawId?.isEmpty == true ? null : rawId;
            int index;
            if (tool['index'] case final int value) {
              if (value < 0) throw const FormatException('Invalid tool index');
              index = value;
            } else if (vendorId != null &&
                _calls.values.any((b) => b.callId == vendorId)) {
              index = _calls.entries
                  .firstWhere((e) => e.value.callId == vendorId)
                  .key;
            } else if (_calls.length <= 1) {
              index = _calls.isEmpty ? 0 : _calls.keys.single;
              if (vendorId != null &&
                  _calls[index]?.callId.isNotEmpty == true &&
                  _calls[index]!.callId != vendorId) {
                index = _nextUnusedIndex();
              }
            } else if (vendorId != null &&
                _calls.values.every((b) => b.callId.isNotEmpty)) {
              index = _nextUnusedIndex();
            } else {
              throw const FormatException('Ambiguous tool index');
            }
            final fn = tool['function'] as Map? ?? {};
            _updateCall(
              index,
              vendorId,
              fn['name'] as String? ?? '',
              fn['arguments'] as String? ?? '',
              chunks,
            );
          }
        }
      case AiProtocol.anthropic:
        final index = data['index'] as int? ?? 0;
        switch (data['type']) {
          case 'message_start':
            _input =
                data['message']?['usage']?['input_tokens'] as int? ?? _input;
            chunks.add(Usage(inputTokens: _input, outputTokens: _output));
          case 'content_block_start':
            if (_parts.containsKey(index)) {
              throw const FormatException('Repeated content block');
            }
            final block = Map<String, dynamic>.from(
              data['content_block'] as Map,
            );
            _parts[index] = block;
            final id = _blockId(index);
            switch (block['type']) {
              case 'tool_use':
                final input = block['input'] as Map? ?? {};
                _updateCall(
                  index,
                  block['id'] as String?,
                  block['name'] as String? ?? '',
                  input.isEmpty ? '' : jsonEncode(input),
                  chunks,
                );
              case 'text':
                chunks.add(TextStart(id));
                final text = block['text'] as String? ?? '';
                if (text.isNotEmpty) chunks.add(TextDelta(id: id, text: text));
              case 'thinking':
                chunks.add(ReasoningStart(id));
                final text = block['thinking'] as String? ?? '';
                if (text.isNotEmpty) {
                  chunks.add(ReasoningDelta(id: id, text: text));
                }
            }
          case 'content_block_delta':
            final block = _parts[index];
            if (block == null || _closedBlocks.contains(index)) {
              throw const FormatException('Unknown content block');
            }
            final delta = data['delta'] as Map;
            final id = _blockId(index);
            switch (delta['type']) {
              case 'text_delta':
                final text = delta['text'] as String;
                block['text'] = (block['text'] ?? '').toString() + text;
                chunks.add(TextDelta(id: id, text: text));
              case 'thinking_delta':
                final text = delta['thinking'] as String;
                block['thinking'] = (block['thinking'] ?? '').toString() + text;
                chunks.add(ReasoningDelta(id: id, text: text));
              case 'signature_delta':
                block['signature'] =
                    (block['signature'] ?? '').toString() +
                    delta['signature'].toString();
              case 'input_json_delta':
                _updateCall(
                  index,
                  null,
                  '',
                  delta['partial_json'] as String? ?? '',
                  chunks,
                );
            }
          case 'content_block_stop':
            _closeBlock(index, chunks);
          case 'message_delta':
            _finish = data['delta']?['stop_reason'] as String? ?? _finish;
            _output = data['usage']?['output_tokens'] as int? ?? _output;
            chunks.add(Usage(inputTokens: _input, outputTokens: _output));
          case 'message_stop':
            _finish ??= 'end_turn';
        }
      case AiProtocol.gemini:
        if (data['usageMetadata'] case final Map usage) {
          _input = usage['promptTokenCount'] as int? ?? _input;
          _output = usage['candidatesTokenCount'] as int? ?? _output;
          chunks.add(Usage(inputTokens: _input, outputTokens: _output));
        }
        for (final candidate
            in (data['candidates'] as List? ?? []).whereType<Map>().take(1)) {
          _finish = candidate['finishReason'] as String? ?? _finish;
          for (final raw
              in (candidate['content']?['parts'] as List? ?? [])
                  .whereType<Map>()) {
            final part = Map<String, dynamic>.from(raw);
            _parts[_parts.length] = part;
            if (part['text'] case final String text) {
              chunks.addAll(
                part['thought'] == true
                    ? _emitter.reasoning(text)
                    : _emitter.text(text),
              );
            }
            if (part['functionCall'] case final Map fn) {
              chunks.addAll(_emitter.close());
              final index = _calls.length;
              _updateCall(
                index,
                (fn['id'] ?? 'gemini_${_emitter.scope}_$index') as String,
                fn['name'] as String? ?? '',
                jsonEncode(fn['args'] ?? {}),
                chunks,
              );
              _closeCall(index, chunks);
            }
          }
        }
        if (data['promptFeedback']?['blockReason'] != null) {
          throw StateError('Provider blocked the prompt');
        }
    }
    if (_parts.length > 2048) {
      throw const FormatException('Provider response limit exceeded');
    }
    return chunks;
  }

  void _updateCall(
    int index,
    String? callId,
    String name,
    String input,
    List<StreamChunk> chunks,
  ) {
    if (callId?.isEmpty == true) callId = null;
    if (_ended.contains(index)) {
      throw const FormatException('Tool input after completion');
    }
    final existing = _calls[index];
    if (existing == null && _calls.length >= 32) {
      throw const FormatException('Provider response limit exceeded');
    }
    final buffer = _calls.putIfAbsent(
      index,
      () => _CallBuffer(_emitter.nextId('tool')),
    );
    if (callId != null && callId.isNotEmpty) {
      if (buffer.callId.isNotEmpty && buffer.callId != callId) {
        throw const FormatException('Conflicting tool call ID');
      }
      buffer.callId = callId;
    }
    buffer.name += name;
    buffer.append(input);
    if (existing == null) {
      chunks.add(ToolCallStart(id: buffer.id, callId: callId, toolName: name));
      if (input.isNotEmpty) {
        chunks.add(ToolCallDelta(id: buffer.id, inputDelta: input));
      }
    } else {
      chunks.add(
        ToolCallDelta(
          id: buffer.id,
          callId: callId,
          toolNameDelta: name,
          inputDelta: input,
        ),
      );
    }
  }

  int _nextUnusedIndex() {
    var index = 0;
    while (_calls.containsKey(index)) {
      index++;
    }
    return index;
  }

  void _closeCall(int index, List<StreamChunk> chunks) {
    if (_ended.contains(index)) return;
    final buffer = _calls[index]!;
    final call = buffer.finish();
    if (!_callIds.add(call.id)) {
      throw const FormatException('Duplicate tool call ID');
    }
    if (protocol == AiProtocol.anthropic) {
      _parts[index]?['input'] = call.arguments;
    }
    _ended.add(index);
    chunks.add(ToolCallEnd(id: buffer.id, call: call));
  }

  void _closeBlock(int index, List<StreamChunk> chunks) {
    if (!_closedBlocks.add(index)) return;
    if (_calls.containsKey(index)) {
      _closeCall(index, chunks);
    } else if (_parts[index]?['type'] == 'thinking') {
      chunks.add(ReasoningEnd(_blockId(index)));
    } else if (_parts[index]?['type'] == 'text') {
      chunks.add(TextEnd(_blockId(index)));
    }
  }

  List<StreamChunk> finish({bool doneMarker = false}) {
    if (doneMarker && protocol == AiProtocol.openai) _finish ??= 'stop';
    if (_finish == null) {
      throw StateError('Provider stream interrupted before completion');
    }
    final chunks = <StreamChunk>[..._emitter.close()];
    if (protocol == AiProtocol.anthropic) {
      for (final index in _parts.keys) {
        _closeBlock(index, chunks);
      }
    } else {
      for (final index in _calls.keys) {
        _closeCall(index, chunks);
      }
    }
    chunks.add(Usage(inputTokens: _input, outputTokens: _output));
    chunks.add(
      Finish(
        stopReason: _finish!,
        providerParts: List.unmodifiable(_parts.values),
      ),
    );
    return chunks;
  }
}

class _CallBuffer {
  _CallBuffer(this.id);
  final String id;
  String callId = '', name = '', json = '';
  void append(String value) {
    if (json.length + value.length > 128 * 1024) {
      throw const FormatException('Tool arguments exceed limit');
    }
    json += value;
  }

  AiToolCall finish() {
    Object? args;
    try {
      args = jsonDecode(json.isEmpty ? '{}' : json);
    } on FormatException {
      throw const FormatException('Invalid tool arguments JSON');
    }
    if (callId.isEmpty || name.isEmpty || args is! Map<String, dynamic>) {
      throw const FormatException('Invalid tool call');
    }
    return AiToolCall(id: callId, name: name, arguments: args);
  }
}
