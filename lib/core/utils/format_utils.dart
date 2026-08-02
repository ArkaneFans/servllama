import 'dart:math';

/// Human-readable byte counts and durations for the model/download UI.
class FormatUtils {
  const FormatUtils._();

  static const List<String> _units = <String>['B', 'KB', 'MB', 'GB', 'TB'];

  /// Binary units (1024), matching what file managers and model hubs report.
  static String bytes(int value) {
    if (value <= 0) {
      return '0 B';
    }
    final exponent = min((log(value) / log(1024)).floor(), _units.length - 1);
    final scaled = value / pow(1024, exponent);
    final digits = exponent == 0 ? 0 : (scaled < 10 ? 2 : 1);
    return '${scaled.toStringAsFixed(digits)} ${_units[exponent]}';
  }

  static String bytesPerSecond(double value) =>
      value <= 0 ? '0 B' : bytes(value.round());

  /// Compact duration for ETAs: `2 分 26 秒` style is built by the caller from
  /// localized parts, so this stays digits-only.
  static String shortDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }
    if (totalSeconds < 3600) {
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return '${minutes}m ${seconds}s';
    }
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  static String compactCount(int value) {
    if (value < 1000) {
      return '$value';
    }
    if (value < 1000000) {
      return '${(value / 1000).toStringAsFixed(value < 10000 ? 1 : 0)}k';
    }
    return '${(value / 1000000).toStringAsFixed(1)}M';
  }
}
