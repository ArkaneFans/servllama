import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/services/foreground_task_service.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';

class LlamaServerService {
  static final LlamaServerService _instance = LlamaServerService._internal();

  factory LlamaServerService() => _instance;

  LlamaServerService._internal();

  static const String _assetDirectoryPath =
      'assets/bin/android/arm64-v8a';
  static const String _manifestAssetPath =
      'assets/bin/llama_server_manifest.json';
  static const String _binaryName = 'llama-server';
  static const String _binaryDirectoryName = 'bin';

  final KvStorage _kvStorage = KvStorage.instance;
  final AppLogger _logger = AppLogger.instance;
  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();
  final AppL10nService _l10nService = AppL10nService.instance;
  final ForegroundTaskService _foregroundTaskService = ForegroundTaskService();
  bool _foregroundTaskInitialized = false;

  Process? _process;
  bool _lastRunningState = false;

  Stream<String> get logStream => _logger
      .streamFor(LogChannel.server)
      .map((entry) => entry.formattedMessage);
  Stream<bool> get runningStateStream => _runningStateController.stream;

  bool get isRunning => _process != null;

  void initForegroundTask() {
    if (_foregroundTaskInitialized) return;
    _foregroundTaskService.init();
    _foregroundTaskInitialized = true;
  }

  Future<String> _getBinaryDirectoryPath() async {
    final directory = await getApplicationSupportDirectory();
    return '${directory.path}/$_binaryDirectoryName';
  }

  Future<String> _getBinaryPath() async {
    final binaryDirectoryPath = await _getBinaryDirectoryPath();
    return '$binaryDirectoryPath/$_binaryName';
  }

  Future<bool> copyBinaryFromAssets() async {
    try {
      final bundledVersion = await _loadBundledVersion();
      await _installBundledBinary(
        bundledVersion: bundledVersion,
      );
      return true;
    } catch (error) {
      _logger.error(
        'Failed to install llama-server when copying binary from assets',
        channel: LogChannel.server,
        inMemory: true,
        error: error,
      );
      return false;
    }
  }

  Future<bool> startServer({List<String>? args}) async {
    if (_process != null) {
      _logger.warning('Server is already running', channel: LogChannel.server, inMemory: true);
      return false;
    }

    try {
      final binaryPath = await _ensureBinaryReady();
      final binaryDirectoryPath = await _getBinaryDirectoryPath(); // 获取存放库的目录
      final arguments = args ?? <String>[];

      _logger.info('Starting llama-server...', channel: LogChannel.server, inMemory: true);
      _logger.info(
        'Command: $binaryPath ${arguments.join(' ')}',
        channel: LogChannel.server,
        inMemory: true,
      );

      final process = await Process.start(
        binaryPath,
        arguments,
        runInShell: false,
        environment: {
          'LD_LIBRARY_PATH': binaryDirectoryPath,
        },
      );

      _process = process;
      _emitRunningState(true);

      await _foregroundTaskService.start(
        notificationTitle: _l10nService.current.serverForegroundNotificationTitle,
        notificationText: _l10nService.current.serverForegroundNotificationText,
      );

      process.stdout.transform(utf8.decoder).listen(_handleStdout);
      process.stderr.transform(utf8.decoder).listen(_handleStderr);
      process.exitCode.then((code) async {
        _logger.info('Server exited with code: $code', channel: LogChannel.server, inMemory: true);
        _process = null;
        _emitRunningState(false);

        await _foregroundTaskService.stop();
      });

      _logger.info(
        'Server started successfully, PID: ${process.pid}',
        channel: LogChannel.server,
        inMemory: true,
      );
      return true;
    } catch (error) {
      _logger.error('Server started failed', channel: LogChannel.server, inMemory: true, error: error);
      _process = null;
      _emitRunningState(false);

      await _foregroundTaskService.stop();

      return false;
    }
  }

  Future<String> _ensureBinaryReady() async {
    final bundledVersion = await _loadBundledVersion();
    final binaryPath = await _getBinaryPath();
    final targetFile = File(binaryPath);
    final installedVersion = await _getInstalledVersion();
    final hasInstalledBinary = await targetFile.exists();

    if (hasInstalledBinary && installedVersion == bundledVersion) {
      return binaryPath;
    }

    if (!hasInstalledBinary) {
      _logger.info(
        'Detected that the llama-server is not installed, installing built-in version $bundledVersion...',
        channel: LogChannel.server,
        inMemory: true,
      );
    } else if (installedVersion == null) {
      _logger.info(
        'Detected that the local llama-server is missing version records, overwriting and installing the built-in version $bundledVersion...',
        channel: LogChannel.server,
        inMemory: true,
      );
    } else {
      _logger.info(
        'Detected a change in llama-server version (Installed: $installedVersion, Bundled: $bundledVersion), updating...',
        channel: LogChannel.server,
        inMemory: true,
      );
    }

    await _installBundledBinary(
      bundledVersion: bundledVersion,
    );
    return binaryPath;
  }

  Future<String> _loadBundledVersion() async {
    final manifestContent = await rootBundle.loadString(_manifestAssetPath);
    final decoded = jsonDecode(manifestContent);
    if (decoded is! Map) {
      throw const FormatException(
        'llama-server manifest must be a JSON object',
      );
    }

    final version = decoded['version']?.toString().trim() ?? '';
    if (version.isEmpty) {
      throw const FormatException(
        'llama-server manifest is missing a non-empty version',
      );
    }
    return version;
  }

  Future<String?> _getInstalledVersion() async {
    final storedVersion = await _kvStorage.getString(
      ServerPrefsKeys.llamaServerInstalledVersion,
    );
    final normalizedVersion = storedVersion?.trim();
    if (normalizedVersion == null || normalizedVersion.isEmpty) {
      return null;
    }
    return normalizedVersion;
  }

  Future<void> _installBundledBinary({
    required String bundledVersion,
  }) async {
    final targetDir = Directory(await _getBinaryDirectoryPath());
    await targetDir.create(recursive: true);

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    
    final assetsToCopy = manifest
        .listAssets()
        .where((path) => path.startsWith('$_assetDirectoryPath/'))
        .toList();

    if (assetsToCopy.isEmpty) {
      throw Exception('No assets found in $_assetDirectoryPath');
    }

    for (final assetPath in assetsToCopy) {
      final fileName = assetPath.split('/').last;
      final targetFile = File('${targetDir.path}/$fileName');
      final tempFile = File('${targetFile.path}.tmp');

      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }

        final byteData = await rootBundle.load(assetPath);
        final bytes = byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );

        await tempFile.writeAsBytes(bytes, flush: true);
        
        await _markExecutable(tempFile.path);

        if (await targetFile.exists()) {
          await targetFile.delete();
        }
        await tempFile.rename(targetFile.path);
        
        _logger.info('Extracted: $fileName', channel: LogChannel.server, inMemory: true);
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    }

    await _kvStorage.setString(
      ServerPrefsKeys.llamaServerInstalledVersion,
      bundledVersion,
    );
    _logger.info(
      'Installed llama-server and dependencies version $bundledVersion',
      channel: LogChannel.server,
      inMemory: true,
    );
  }

  Future<void> _markExecutable(String binaryPath) async {
    final result = await Process.run('chmod', <String>['+x', binaryPath]);
    if (result.exitCode == 0) {
      return;
    }

    throw ProcessException(
      'chmod',
      <String>['+x', binaryPath],
      '${result.stderr}',
      result.exitCode,
    );
  }

  void _handleStdout(String data) {
    final lines = data.split('\n');
    for (final line in lines) {
      final message = line.trim();
      if (message.isNotEmpty) {
        _logger.info(message, channel: LogChannel.server, inMemory: true);
      }
    }
  }

  void _handleStderr(String data) {
    final lines = data.split('\n');
    for (final line in lines) {
      final message = line.trim();
      if (message.isNotEmpty) {
        _logger.info(message, channel: LogChannel.server, inMemory: true);
      }
    }
  }

  Future<bool> stopServer() async {
    if (_process == null) {
      _logger.warning('Server is not running', channel: LogChannel.server, inMemory: true);
      return false;
    }

    try {
      _logger.info('Stopping service...', channel: LogChannel.server, inMemory: true);
      _process!.kill(ProcessSignal.sigkill);
      _process = null;
      _emitRunningState(false);

      await _foregroundTaskService.stop();

      return true;
    } catch (error) {
      _logger.error('Failed to stop service', channel: LogChannel.server, inMemory: true, error: error);
      _process = null;
      _emitRunningState(false);

      await _foregroundTaskService.stop();

      return false;
    }
  }

  void dispose() {
    stopServer();
    _runningStateController.close();
    _foregroundTaskService.dispose();
  }

  void _emitRunningState(bool isRunning) {
    if (_lastRunningState == isRunning) {
      return;
    }
    _lastRunningState = isRunning;
    _runningStateController.add(isRunning);
  }
}