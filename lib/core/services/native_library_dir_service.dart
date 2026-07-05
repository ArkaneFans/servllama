import 'package:flutter/services.dart';

class NativeLibraryDirService {
  NativeLibraryDirService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'com.arkanefans.servllama/native_libs';

  final MethodChannel _channel;
  String? _cachedDir;

  Future<String> getNativeLibraryDir() async {
    final cached = _cachedDir;
    if (cached != null) {
      return cached;
    }
    final dir = await _channel.invokeMethod<String>('getNativeLibraryDir');
    if (dir == null || dir.isEmpty) {
      throw StateError('Native library directory is unavailable');
    }
    _cachedDir = dir;
    return dir;
  }
}
