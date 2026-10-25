import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:servllama/app/bootstrap/startup_task.dart';
import 'package:servllama/core/logging/app_logger.dart';

/// Lives above the Navigator so interaction on any route can defer warm-up.
/// In-flight I/O settles normally; only the next optional step is deferred.
class AppIdleWarmup extends StatefulWidget {
  const AppIdleWarmup({
    super.key,
    required this.ready,
    required this.createTasks,
    required this.child,
    this.onReady,
    this.activity,
    this.isBusy,
  });

  final ValueListenable<bool> ready;
  final Future<List<StartupTask>> Function() createTasks;
  final FutureOr<void> Function()? onReady;
  final Listenable? activity;
  final bool Function()? isBusy;
  final Widget child;

  @override
  State<AppIdleWarmup> createState() => _AppIdleWarmupState();
}

class _AppIdleWarmupState extends State<AppIdleWarmup>
    with WidgetsBindingObserver {
  final _pointers = <int>{};
  List<StartupTask> _tasks = const [];
  int _next = 0;
  bool _started = false, _queued = false, _running = false;
  late bool _foreground;

  bool get _eligible => mounted && widget.ready.value && _foreground;
  bool get _canRun =>
      _eligible && _pointers.isEmpty && !(widget.isBusy?.call() ?? false);

  @override
  void initState() {
    super.initState();
    final binding = WidgetsBinding.instance;
    _foreground =
        binding.lifecycleState == null ||
        binding.lifecycleState == AppLifecycleState.resumed;
    binding.addObserver(this);
    widget.ready.addListener(_schedule);
    widget.activity?.addListener(_schedule);
    _schedule();
  }

  @override
  void didUpdateWidget(AppIdleWarmup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ready != widget.ready) {
      oldWidget.ready.removeListener(_schedule);
      widget.ready.addListener(_schedule);
    }
    if (oldWidget.activity != widget.activity) {
      oldWidget.activity?.removeListener(_schedule);
      widget.activity?.addListener(_schedule);
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _pointers.clear();
    }
    _schedule();
  }

  void _schedule() {
    if (!(_started ? _canRun : _eligible) || _queued || _running) return;
    if (_started && _next >= _tasks.length) return;
    _queued = true;
    final binding = WidgetsBinding.instance;
    // Provider notifications may have requested a frame. Let it paint first.
    binding.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!(_started ? _canRun : _eligible)) {
        _queued = false;
        return;
      }
      if (!_started) {
        _queued = false;
        unawaited(_start());
        return;
      }
      Timer.run(() {
        _queued = false;
        if (!_canRun) return;
        // scheduleTask(Priority.idle) repeatedly posts zero-delay timers when
        // denied. Check once per frame instead, as animations already tick.
        if (!binding.schedulingStrategy(
          priority: Priority.idle.value,
          scheduler: binding,
        )) {
          _schedule();
          return;
        }
        unawaited(_runNext());
      });
    });
    binding.ensureVisualUpdate();
  }

  Future<void> _start() async {
    _started = true;
    _running = true;
    try {
      // Real background services are not optional warm-up and must not be
      // abandoned when the user starts interacting with the app.
      await widget.onReady?.call();
    } catch (error) {
      AppLogger.instance.event(
        'app.startup.background_start_failed',
        level: LogLevel.warning,
        fields: AppLogger.errorFields(error),
      );
    }
    if (!mounted) return;
    try {
      _tasks = await widget.createTasks();
    } catch (error) {
      AppLogger.instance.event(
        'app.startup.warmup_plan_failed',
        level: LogLevel.warning,
        fields: AppLogger.errorFields(error),
      );
    } finally {
      _running = false;
      if (mounted) _schedule();
    }
  }

  Future<void> _runNext() async {
    if (_running || _next >= _tasks.length) return;
    _running = true;
    final task = _tasks[_next++];
    try {
      await task.run(phase: 'warmup');
    } catch (_) {
      // Optional failures are already logged. Pages can retry their loaders.
    } finally {
      _running = false;
      if (mounted) _schedule();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.ready.removeListener(_schedule);
    widget.activity?.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) => _pointers.add(event.pointer),
    onPointerUp: (event) {
      _pointers.remove(event.pointer);
      _schedule();
    },
    onPointerCancel: (event) {
      _pointers.remove(event.pointer);
      _schedule();
    },
    child: widget.child,
  );
}
