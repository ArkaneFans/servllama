import 'dart:async';

/// At most one write in flight and one latest pending snapshot. UI deltas do not
/// wait for disk. Tool boundaries and finalization explicitly flush this writer.
class ChatCheckpointWriter {
  ChatCheckpointWriter({this.interval = const Duration(milliseconds: 300)});
  final Duration interval;
  Timer? _timer;
  Future<void>? _writing;
  Future<void> Function()? _pending;
  (Object, StackTrace)? _failure;

  void add(Future<void> Function() write) {
    _pending = write;
    _timer ??= Timer(interval, () {
      _timer = null;
      if (_writing == null) _start();
    });
  }

  void _start() {
    final write = _pending;
    if (write == null) return;
    _pending = null;
    _writing = Future.sync(write)
        .catchError((Object error, StackTrace stack) {
          _failure = (error, stack);
        })
        .whenComplete(() {
          _writing = null;
          if (_pending != null && _timer == null) {
            _timer = Timer(interval, () {
              _timer = null;
              _start();
            });
          }
        });
  }

  Future<void> flush() async {
    do {
      _timer?.cancel();
      _timer = null;
      if (_writing == null) _start();
      await _writing;
    } while (_pending != null || _writing != null);
    final failure = _failure;
    _failure = null;
    if (failure != null) Error.throwWithStackTrace(failure.$1, failure.$2);
  }
}
