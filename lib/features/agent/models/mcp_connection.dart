import 'package:flutter/foundation.dart';

enum McpConnectionStatus { disconnected, connecting, connected, failed }

@immutable
class McpConnectionState {
  const McpConnectionState({
    this.status = McpConnectionStatus.disconnected,
    this.toolCount = 0,
    this.error,
  });

  final McpConnectionStatus status;
  final int toolCount;
  final String? error;

  bool get isConnected => status == McpConnectionStatus.connected;
  bool get hasError =>
      status == McpConnectionStatus.failed && error?.isNotEmpty == true;

  McpConnectionState copyWith({
    McpConnectionStatus? status,
    int? toolCount,
    String? error,
    bool clearError = false,
  }) => McpConnectionState(
    status: status ?? this.status,
    toolCount: toolCount ?? this.toolCount,
    error: clearError ? null : error ?? this.error,
  );
}
