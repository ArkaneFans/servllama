import 'dart:async';

import 'package:flutter/material.dart';

class ChatConversationTransition extends StatefulWidget {
  const ChatConversationTransition({
    super.key,
    required this.conversationKey,
    required this.child,
    this.onConversationCommitted,
    this.animateBody = true,
    this.readyToCommit = true,
    this.switchDelay = Duration.zero,
    this.maxUnreadyDelay = const Duration(milliseconds: 320),
    this.duration = const Duration(milliseconds: 180),
    this.curve = Curves.easeOutCubic,
  });

  final String conversationKey;
  final Widget child;
  final ValueChanged<String>? onConversationCommitted;
  final bool animateBody;
  final bool readyToCommit;
  final Duration switchDelay;
  final Duration maxUnreadyDelay;
  final Duration duration;
  final Curve curve;

  @override
  State<ChatConversationTransition> createState() =>
      _ChatConversationTransitionState();
}

class _ChatConversationTransitionState extends State<ChatConversationTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _opacity;
  late String _displayedKey;
  late Widget _displayedChild;
  String? _pendingKey;
  Widget? _pendingChild;
  bool _pendingReadyToCommit = true;
  Timer? _pendingSwitchDelayTimer;
  Timer? _pendingMaxUnreadyDelayTimer;
  Completer<void>? _pendingSwitchDelayCompleter;
  Completer<void>? _pendingMaxUnreadyDelayCompleter;
  Future<void>? _pendingSwitchDelayFuture;
  Future<void>? _pendingMaxUnreadyDelayFuture;
  bool _isSwitching = false;
  int _switchGeneration = 0;
  Completer<void>? _switchChangedCompleter;
  Completer<void>? _pendingReadyChangedCompleter;

  @override
  void initState() {
    super.initState();
    _displayedKey = widget.conversationKey;
    _displayedChild = widget.child;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
  }

  @override
  void didUpdateWidget(covariant ChatConversationTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.curve != widget.curve) {
      _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    }

    if (widget.conversationKey == _displayedKey) {
      _displayedChild = widget.child;
      _pendingKey = null;
      _pendingChild = null;
      _pendingReadyToCommit = true;
      _clearPendingTiming();
      _switchGeneration += 1;
      _notifySwitchChanged();
      _notifyPendingReadyChanged();
      if (widget.animateBody && _controller.value < 1) {
        _controller.forward();
      } else if (!widget.animateBody) {
        _controller.value = 1;
      }
      return;
    }

    if (_pendingKey == widget.conversationKey) {
      _pendingChild = widget.child;
      _pendingReadyToCommit = widget.readyToCommit;
      if (_pendingReadyToCommit) {
        _clearPendingMaxUnreadyDelay();
      } else {
        _pendingMaxUnreadyDelayFuture ??= _timerFuture(
          widget.maxUnreadyDelay,
          (timer) => _pendingMaxUnreadyDelayTimer = timer,
          (completer) => _pendingMaxUnreadyDelayCompleter = completer,
        );
      }
    } else {
      _clearPendingTiming();
      _pendingKey = widget.conversationKey;
      _pendingChild = widget.child;
      _pendingReadyToCommit = widget.readyToCommit;
      _pendingSwitchDelayFuture = _timerFuture(
        widget.switchDelay,
        (timer) => _pendingSwitchDelayTimer = timer,
        (completer) => _pendingSwitchDelayCompleter = completer,
      );
      _pendingMaxUnreadyDelayFuture = _pendingReadyToCommit
          ? null
          : _timerFuture(
              widget.maxUnreadyDelay,
              (timer) => _pendingMaxUnreadyDelayTimer = timer,
              (completer) => _pendingMaxUnreadyDelayCompleter = completer,
            );
      _switchGeneration += 1;
      _notifySwitchChanged();
    }
    _notifyPendingReadyChanged();
    _ensureSwitching();
  }

  void _ensureSwitching() {
    if (_isSwitching) {
      if (_controller.status == AnimationStatus.forward) {
        _controller.reverse();
      }
      return;
    }
    unawaited(_runSwitch());
  }

  Future<void> _runSwitch() async {
    _isSwitching = true;
    try {
      while (mounted && _pendingKey != null) {
        final generation = _switchGeneration;
        if (widget.animateBody) {
          await _animate(reverse: true);
        } else {
          _controller.stop();
          _controller.value = 1;
          final completedDelay = await _waitForSwitchDelay(generation);
          if (!completedDelay) {
            continue;
          }
        }
        if (!mounted) {
          return;
        }
        if (generation != _switchGeneration) {
          continue;
        }
        await _waitUntilReadyOrExpired(generation: generation);
        if (!mounted) {
          return;
        }
        if (generation != _switchGeneration) {
          continue;
        }
        final committedKey = _pendingKey;
        final committedChild = _pendingChild;
        if (committedKey == null || committedChild == null) {
          break;
        }
        setState(() {
          _displayedKey = committedKey;
          _displayedChild = committedChild;
          _pendingKey = null;
          _pendingChild = null;
          _pendingReadyToCommit = true;
          _clearPendingTiming();
        });
        try {
          await WidgetsBinding.instance.endOfFrame;
        } catch (_) {}
        if (!mounted) {
          return;
        }
        widget.onConversationCommitted?.call(committedKey);
        if (widget.animateBody && _pendingKey == null) {
          await _animate(reverse: false);
        }
      }
    } finally {
      _isSwitching = false;
      if (mounted && _pendingKey != null) {
        _ensureSwitching();
      }
    }
  }

  Future<void> _waitUntilReadyOrExpired({required int generation}) async {
    while (mounted &&
        generation == _switchGeneration &&
        _pendingKey != null &&
        !_pendingReadyToCommit) {
      final expired = await _waitForReadyChangeOrMaxDelay();
      if (expired) {
        return;
      }
    }
  }

  Future<bool> _waitForSwitchDelay(int generation) async {
    final delayFuture = _pendingSwitchDelayFuture;
    if (delayFuture == null) {
      return true;
    }
    final completer = Completer<void>();
    _switchChangedCompleter = completer;
    try {
      final completedDelay = await Future.any<bool>([
        delayFuture.then((_) => true),
        completer.future.then((_) => false),
      ]);
      return mounted && generation == _switchGeneration && completedDelay;
    } finally {
      if (identical(_switchChangedCompleter, completer)) {
        _switchChangedCompleter = null;
      }
    }
  }

  Future<bool> _waitForReadyChangeOrMaxDelay() async {
    final maxDelayFuture = _pendingMaxUnreadyDelayFuture;
    if (maxDelayFuture == null) {
      return true;
    }
    final completer = Completer<void>();
    _pendingReadyChangedCompleter = completer;
    try {
      return Future.any<bool>([
        maxDelayFuture.then((_) => true),
        completer.future.then((_) => false),
      ]);
    } finally {
      if (identical(_pendingReadyChangedCompleter, completer)) {
        _pendingReadyChangedCompleter = null;
      }
    }
  }

  Future<void>? _timerFuture(
    Duration delay,
    ValueChanged<Timer> onTimer,
    ValueChanged<Completer<void>> onCompleter,
  ) {
    if (delay <= Duration.zero) {
      return null;
    }
    final completer = Completer<void>();
    onCompleter(completer);
    final timer = Timer(delay, () {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    onTimer(timer);
    return completer.future;
  }

  void _clearPendingTiming() {
    _pendingSwitchDelayTimer?.cancel();
    if (_pendingSwitchDelayCompleter != null &&
        !_pendingSwitchDelayCompleter!.isCompleted) {
      _pendingSwitchDelayCompleter!.complete();
    }
    _clearPendingMaxUnreadyDelay();
    _pendingSwitchDelayTimer = null;
    _pendingSwitchDelayCompleter = null;
    _pendingSwitchDelayFuture = null;
  }

  void _clearPendingMaxUnreadyDelay() {
    _pendingMaxUnreadyDelayTimer?.cancel();
    if (_pendingMaxUnreadyDelayCompleter != null &&
        !_pendingMaxUnreadyDelayCompleter!.isCompleted) {
      _pendingMaxUnreadyDelayCompleter!.complete();
    }
    _pendingMaxUnreadyDelayTimer = null;
    _pendingMaxUnreadyDelayCompleter = null;
    _pendingMaxUnreadyDelayFuture = null;
  }

  void _notifySwitchChanged() {
    final completer = _switchChangedCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _notifyPendingReadyChanged() {
    final completer = _pendingReadyChangedCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  Future<void> _animate({required bool reverse}) async {
    try {
      if (reverse) {
        await _controller.reverse().orCancel;
      } else {
        await _controller.forward().orCancel;
      }
    } on TickerCanceled {
      // A newer switch or dispose interrupted the current leg.
    }
  }

  @override
  void dispose() {
    _notifySwitchChanged();
    _notifyPendingReadyChanged();
    _clearPendingTiming();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(
      key: ValueKey<String>('chat_conversation_transition_$_displayedKey'),
      child: _displayedChild,
    );
    if (!widget.animateBody) {
      return IgnorePointer(ignoring: _pendingKey != null, child: child);
    }
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        return IgnorePointer(
          ignoring: _controller.value < 1 || _pendingKey != null,
          child: FadeTransition(opacity: _opacity, child: child),
        );
      },
    );
  }
}
