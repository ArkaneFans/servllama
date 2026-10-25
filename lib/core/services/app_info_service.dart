import 'package:mnn_engine/mnn_engine.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:servllama/core/services/llama_server_service.dart';

class AppInfo {
  const AppInfo({
    this.app = '\u2014',
    this.llamaCpp = '\u2014',
    this.mnn = '\u2014',
  });
  final String app, llamaCpp, mnn;
}

/// Immutable bundled/platform metadata, shared by all About page visits.
class AppInfoService {
  AppInfo? cached;
  Future<AppInfo>? _loading;

  Future<AppInfo> load() => _loading ??= _load();

  Future<AppInfo> _load() async {
    final values = await Future.wait([
      _label(() async {
        final info = await PackageInfo.fromPlatform();
        return [
          info.version.trim(),
          info.buildNumber.trim(),
        ].where((v) => v.isNotEmpty).join(' / ');
      }),
      _label(() => LlamaServerService().loadBundledVersion()),
      _label(() async {
        final info = await MnnEngine.instance.initialize();
        final commit = info.mnnCommit.trim();
        final short = commit.length > 10 ? commit.substring(0, 10) : commit;
        return short.isEmpty || short == 'unknown'
            ? info.mnnVersion
            : '${info.mnnVersion} \u00b7 $short';
      }),
    ]);
    return cached = AppInfo(
      app: values[0],
      llamaCpp: values[1],
      mnn: values[2],
    );
  }

  Future<String> _label(Future<String> Function() read) async {
    try {
      final value = (await read()).trim();
      return value.isEmpty ? '\u2014' : value;
    } catch (_) {
      return '\u2014';
    }
  }
}
