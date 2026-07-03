import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/services/server_launch_args_builder.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:servllama/core/utils/network_utils.dart';

class ServerProvider extends ChangeNotifier {
  ServerProvider({
    LlamaServerService? serverService,
    ServerLaunchSettingsLoader? settingsLoader,
    ServerLaunchArgsBuilder? launchArgsBuilder,
    ModelStoragePaths? modelStoragePaths,
    KvStorage? kvStorage,
  }) : _serverService = serverService ?? LlamaServerService(),
       _settingsLoader = settingsLoader ?? ServerLaunchSettingsLoader(),
       _launchArgsBuilder =
           launchArgsBuilder ?? const ServerLaunchArgsBuilder(),
       _modelStoragePaths = modelStoragePaths ?? ModelStoragePaths(),
       _kvStorage = kvStorage ?? KvStorage.instance {
    _isRunning = _serverService.isRunning;
    _runningStateSubscription = _serverService.runningStateStream.listen(
      _handleRunningStateChanged,
    );
  }

  final LlamaServerService _serverService;
  final ServerLaunchSettingsLoader _settingsLoader;
  final ServerLaunchArgsBuilder _launchArgsBuilder;
  final ModelStoragePaths _modelStoragePaths;
  final KvStorage _kvStorage;
  late final StreamSubscription<bool> _runningStateSubscription;

  bool _isRunning = false;
  bool _isBusy = false;
  bool _disposed = false;
  String _host = '127.0.0.1';
  int _port = 8080;
  String? _lastError;
  String? _pendingDisplayHost;

  bool get isRunning => _isRunning;
  bool get isBusy => _isBusy;
  String get host => _host;
  int get port => _port;
  String? get lastError => _lastError;

  String get displayAddress {
    if (_host == '0.0.0.0') {
      _refreshDisplayHost();
      return '${_pendingDisplayHost ?? _host}:$_port';
    }
    return '$_host:$_port';
  }

  String get baseUrl => 'http://$displayAddress';

  AppL10nService get _l10nService => AppL10nService.instance;

  void _refreshDisplayHost() {
    NetworkUtils.getLocalIpAddress().then((ip) {
      if (_disposed) {
        return;
      }
      if (ip != null && ip != _pendingDisplayHost) {
        _pendingDisplayHost = ip;
        notifyListeners();
      }
    });
  }

  void setEndpoint({String? host, int? port}) {
    var changed = false;
    if (host != null && host != _host) {
      _host = host;
      changed = true;
    }
    if (port != null && port != _port) {
      _port = port;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void refresh() {
    final running = _serverService.isRunning;
    if (running != _isRunning) {
      _isRunning = running;
      notifyListeners();
    }
  }

  Future<void> loadSavedEndpoint() async {
    try {
      final settings = await _settingsLoader.load();
      setEndpoint(host: settings.host, port: settings.port);
    } catch (_) {}
  }

  Future<void> toggle() async {
    if (_isRunning) {
      await stop();
      return;
    }
    await start();
  }

  Future<void> start() async {
    if (_isBusy) {
      return;
    }

    _lastError = null;
    _isBusy = true;
    notifyListeners();

    try {
      await _requestNotificationPermissionOnce();

      _serverService.initForegroundTask();

      final settings = await _settingsLoader.load();
      final modelsDirectoryPath = await _modelStoragePaths
          .getModelsDirectoryPath();
      setEndpoint(host: settings.host, port: settings.port);
      final started = await _serverService.startServer(
        args: _launchArgsBuilder.build(
          settings,
          modelsDirectoryPath: modelsDirectoryPath,
        ),
      );
      _isRunning = _serverService.isRunning;
      if (!started && !_isRunning) {
        _lastError = _l10nService.current.serverStartFailedCheckLogs;
      }
    } catch (error) {
      _lastError = _l10nService.current.serverStartFailed(error.toString());
      _isRunning = _serverService.isRunning;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (_isBusy) {
      return;
    }

    _lastError = null;
    _isBusy = true;
    notifyListeners();

    try {
      await _serverService.stopServer();
      _isRunning = _serverService.isRunning;
    } catch (error) {
      _lastError = _l10nService.current.serverStopFailed(error.toString());
      _isRunning = _serverService.isRunning;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> _requestNotificationPermissionOnce() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final hasPrompted = await _kvStorage.getBool(
        ServerPrefsKeys.foregroundNotificationPermissionPrompted,
      );
      if (hasPrompted != null) {
        return;
      }

      final notificationPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (notificationPermission == NotificationPermission.granted) {
        await _kvStorage.setBool(
          ServerPrefsKeys.foregroundNotificationPermissionPrompted,
          true,
        );
        return;
      }

      if (notificationPermission != NotificationPermission.denied) {
        return;
      }

      await _kvStorage.setBool(
        ServerPrefsKeys.foregroundNotificationPermissionPrompted,
        true,
      );
      await FlutterForegroundTask.requestNotificationPermission();
    } catch (_) {
      // Notification permission is best-effort and must not block server start.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _runningStateSubscription.cancel();
    super.dispose();
  }

  void _handleRunningStateChanged(bool isRunning) {
    if (_isRunning == isRunning) {
      return;
    }
    _isRunning = isRunning;
    notifyListeners();
  }
}
