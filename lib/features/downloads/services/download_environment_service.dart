import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum DownloadNetworkTransport {
  wifi,
  ethernet,
  cellular,
  other,
  none,
  unknown;

  static DownloadNetworkTransport fromPlatformValue(String? value) {
    for (final transport in DownloadNetworkTransport.values) {
      if (transport.name == value) {
        return transport;
      }
    }
    return DownloadNetworkTransport.unknown;
  }

  bool get isUnmetered =>
      this == DownloadNetworkTransport.wifi ||
      this == DownloadNetworkTransport.ethernet;
}

/// Android-backed environment checks used before and during large downloads.
/// Unknown results never block transfers, which keeps desktop tests and future
/// platforms in a safe degraded mode.
class DownloadEnvironmentService {
  const DownloadEnvironmentService();

  static const MethodChannel _channel = MethodChannel(
    'com.arkanefans.servllama/download_environment',
  );

  Future<DownloadNetworkTransport> networkTransport() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return DownloadNetworkTransport.unknown;
    }
    try {
      final value = await _channel.invokeMethod<String>('networkTransport');
      return DownloadNetworkTransport.fromPlatformValue(value);
    } on PlatformException catch (_) {
      return DownloadNetworkTransport.unknown;
    } on MissingPluginException catch (_) {
      return DownloadNetworkTransport.unknown;
    }
  }

  Future<int?> availableStorageBytes() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      return await _channel.invokeMethod<int>('availableStorageBytes');
    } on PlatformException catch (_) {
      return null;
    } on MissingPluginException catch (_) {
      return null;
    }
  }

  bool allowsDownload({
    required bool wifiOnly,
    required DownloadNetworkTransport transport,
  }) {
    if (transport == DownloadNetworkTransport.none) {
      return false;
    }
    if (!wifiOnly) {
      return true;
    }
    if (transport == DownloadNetworkTransport.cellular) {
      return false;
    }
    return transport.isUnmetered ||
        transport == DownloadNetworkTransport.other ||
        transport == DownloadNetworkTransport.unknown;
  }
}
