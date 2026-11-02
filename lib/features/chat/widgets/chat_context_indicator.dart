import 'dart:async';

import 'package:flutter/material.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/features/chat/models/chat_context_usage.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/services/context_capacity_client.dart';
import 'package:servllama/features/chat/widgets/chat_context_usage_ring.dart';

/// Reads actual usage independently of the scrolling/paginated chat body.
/// Measurements are invalidated immediately; late async results cannot revive
/// another conversation's/model's percentage.
class ChatContextIndicator extends StatefulWidget {
  const ChatContextIndicator({
    super.key,
    required this.provider,
    required this.runtime,
    this.capacityClient,
  });

  final ChatProvider provider;
  final EngineRuntimeProvider? runtime;
  final ContextCapacityClient? capacityClient;

  @override
  State<ChatContextIndicator> createState() => _ChatContextIndicatorState();
}

class _ChatContextIndicatorState extends State<ChatContextIndicator> {
  late final ContextCapacityClient _client =
      widget.capacityClient ?? ContextCapacityClient();
  ChatContextUsage _usage = const ChatContextUsage();
  String? _readKey, _capacityKey;
  Future<int?>? _capacity;
  bool _refreshQueued = false;
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_changed);
    widget.runtime?.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(ChatContextIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider != widget.provider) {
      oldWidget.provider.removeListener(_changed);
      widget.provider.addListener(_changed);
      _readKey = null;
    }
    if (oldWidget.runtime != widget.runtime) {
      oldWidget.runtime?.removeListener(_changed);
      widget.runtime?.addListener(_changed);
      _readKey = null;
      _capacityKey = null;
      _capacity = null;
    }
    _changed();
  }

  void _changed() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    scheduleMicrotask(() {
      _refreshQueued = false;
      if (mounted) unawaited(_refresh());
    });
  }

  String? get _runtimeCapacityKey {
    final p = widget.provider, r = widget.runtime;
    final asset = p.targetAsset;
    if (r == null ||
        !r.isRunning ||
        r.activeEngine != InferenceEngine.llamaCpp ||
        p.currentTarget?.isRemote != false ||
        asset == null ||
        asset.runtimeId != r.activeModelId ||
        asset.engine != r.activeEngine.storageValue) {
      return null;
    }
    return '${r.baseUrl}|${r.activeModelId}|${r.state.startedAt}';
  }

  Future<void> _refresh() async {
    final capacityKey = _runtimeCapacityKey;
    final key = '${widget.provider.contextUsageKey}|$capacityKey';
    if (key == _readKey) return;
    _readKey = key;
    final epoch = ++_epoch;
    // Clear before I/O so edits, drafts, model switches and retries never show
    // a prior percentage while a replacement request is being resolved.
    setState(() => _usage = const ChatContextUsage());
    if (capacityKey != _capacityKey) {
      _capacityKey = capacityKey;
      _capacity = capacityKey == null
          ? Future<int?>.value(null)
          : _client.fetchLlamaCapacity(
              baseUrl: widget.runtime!.baseUrl,
              apiKey: widget.runtime!.apiKey,
            );
    }
    try {
      final values = await Future.wait<int?>([
        widget.provider.loadCurrentContextTokens(),
        _capacity ?? Future<int?>.value(null),
      ]);
      if (!mounted ||
          epoch != _epoch ||
          key != '${widget.provider.contextUsageKey}|$_runtimeCapacityKey') {
        return;
      }
      // A transient property-read failure can be retried on the next context
      // change, but never causes polling or provider traffic for every frame.
      if (capacityKey != null && values[1] == null) _capacityKey = null;
      setState(
        () => _usage = ChatContextUsage(
          usedTokens: values[0],
          capacityTokens: values[1],
        ),
      );
    } catch (_) {
      // Storage/transport failure is unknown, never an estimated percentage.
    }
  }

  @override
  void dispose() {
    ++_epoch;
    widget.provider.removeListener(_changed);
    widget.runtime?.removeListener(_changed);
    if (widget.capacityClient == null) _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChatContextUsageRing(usage: _usage);
}
