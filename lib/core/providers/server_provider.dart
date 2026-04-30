import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:servllama/core/services/llama_server_service.dart';
import 'package:servllama/core/services/model_storage_paths.dart';
import 'package:servllama/core/services/server_launch_args_builder.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';

class ServerProvider extends ChangeNotifier {
  ServerProvider({
    LlamaServerService? serverService,
    ServerLaunchSettingsLoader? settingsLoader,
    ServerLaunchArgsBuilder? launchArgsBuilder,
    ModelStoragePaths? modelStoragePaths,
  }) : _serverService = serverService ?? LlamaServerService(),
       _settingsLoader = settingsLoader ?? ServerLaunchSettingsLoader(),
       _launchArgsBuilder =
           launchArgsBuilder ?? const ServerLaunchArgsBuilder(),
       _modelStoragePaths = modelStoragePaths ?? ModelStoragePaths() {
    _isRunning = _serverService.isRunning;
    _runningStateSubscription = _serverService.runningStateStream.listen(
      _handleRunningStateChanged,
    );
  }

  final LlamaServerService _serverService;
  final ServerLaunchSettingsLoader _settingsLoader;
  final ServerLaunchArgsBuilder _launchArgsBuilder;
  final ModelStoragePaths _modelStoragePaths;
  late final StreamSubscription<bool> _runningStateSubscription;

  bool _isRunning = false;
  bool _isBusy = false;
  String _host = '127.0.0.1';
  int _port = 8080;
  String? _lastError;

  bool get isRunning => _isRunning;
  bool get isBusy => _isBusy;
  String get host => _host;
  int get port => _port;
  String? get lastError => _lastError;

  String get displayAddress => '$_host:$_port';
  String get baseUrl => 'http://$displayAddress';

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
        _lastError = '启动失败，请查看日志。';
      }
    } catch (error) {
      _lastError = '启动失败: $error';
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
      _lastError = '停止失败: $error';
      _isRunning = _serverService.isRunning;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
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
