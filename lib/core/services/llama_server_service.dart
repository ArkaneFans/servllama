import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/services/foreground_task_service.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';

class LlamaServerService {
  static final LlamaServerService _instance = LlamaServerService._internal();

  factory LlamaServerService() => _instance;

  LlamaServerService._internal();

  static const String _assetPath =
      'assets/bin/android/arm64-v8a/llama-server';
  static const String _manifestAssetPath =
      'assets/bin/llama_server_manifest.json';
  static const String _binaryName = 'llama-server';
  static const String _binaryDirectoryName = 'bin';

  final KvStorage _kvStorage = KvStorage.instance;
  final AppLogger _logger = AppLogger.instance;
  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();

  final ForegroundTaskService _foregroundTaskService = ForegroundTaskService();
  bool _foregroundTaskInitialized = false;

  Process? _process;
  bool _lastRunningState = false;

  Stream<String> get logStream => _logger
      .streamFor(LogChannel.server)
      .map((entry) => entry.formattedMessage);
  Stream<bool> get runningStateStream => _runningStateController.stream;

  bool get isRunning => _process != null;

  // Should be called once at app startup or before first use
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
      final binaryPath = await _getBinaryPath();
      await _installBundledBinary(
        targetFile: File(binaryPath),
        bundledVersion: bundledVersion,
      );
      return true;
    } catch (error) {
      _logger.pageError(
        'Failed to install llama-server when copying binary from assets',
        channel: LogChannel.server,
        error: error,
      );
      return false;
    }
  }

  Future<bool> startServer({List<String>? args}) async {
    if (_process != null) {
      _logger.pageWarning('Server is already running', channel: LogChannel.server);
      return false;
    }

    try {
      final binaryPath = await _ensureBinaryReady();
      final arguments = args ?? <String>[];

      _logger.pageInfo('Starting llama-server...', channel: LogChannel.server);
      _logger.pageInfo(
        'Command: $binaryPath ${arguments.join(' ')}',
        channel: LogChannel.server,
      );

      final process = await Process.start(
        binaryPath,
        arguments,
        runInShell: false,
      );

      _process = process;
      _emitRunningState(true);

      // final address = _extractHostFromArgs(arguments);
      await _foregroundTaskService.start(
        notificationTitle: 'ServLlama is running',
        notificationText: 'ServLlama server is running in the background',
      );

      process.stdout.transform(utf8.decoder).listen(_handleStdout);
      process.stderr.transform(utf8.decoder).listen(_handleStderr);
      process.exitCode.then((code) async {
        _logger.pageInfo('Server exited with code: $code', channel: LogChannel.server);
        _process = null;
        _emitRunningState(false);

        await _foregroundTaskService.stop();
      });

      _logger.pageInfo(
        'Server started successfully,PID: ${process.pid}',
        channel: LogChannel.server,
      );
      return true;
    } catch (error) {
      _logger.pageError('Server started failed', channel: LogChannel.server, error: error);
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
      _logger.pageInfo(
        'Detected that the llama-server is not installed, installing built-in version $bundledVersion...',
        channel: LogChannel.server,
      );
    } else if (installedVersion == null) {
      _logger.pageInfo(
        'Detected that the local llama-server is missing version records, overwriting and installing the built-in version $bundledVersion...',
        channel: LogChannel.server,
      );
    } else {
      _logger.pageInfo(
        'Detected a change in llama-server version (Installed: $installedVersion, Bundled: $bundledVersion), updating...',
        channel: LogChannel.server,
      );
    }

    await _installBundledBinary(
      targetFile: targetFile,
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
    required File targetFile,
    required String bundledVersion,
  }) async {
    final tempFile = File('${targetFile.path}.tmp');
    try {
      await targetFile.parent.create(recursive: true);

      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final byteData = await rootBundle.load(_assetPath);
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

      await _kvStorage.setString(
        ServerPrefsKeys.llamaServerInstalledVersion,
        bundledVersion,
      );
      _logger.pageInfo(
        'Installed llama-server version $bundledVersion',
        channel: LogChannel.server,
      );
    } finally {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
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
        _logger.serverStdout(message);
      }
    }
  }

  void _handleStderr(String data) {
    final lines = data.split('\n');
    for (final line in lines) {
      final message = line.trim();
      if (message.isNotEmpty) {
        _logger.serverStderr(message);
      }
    }
  }

  Future<bool> stopServer() async {
    if (_process == null) {
      _logger.pageWarning('Server is not running', channel: LogChannel.server);
      return false;
    }

    try {
      _logger.pageInfo('Stopping service...', channel: LogChannel.server);
      _process!.kill(ProcessSignal.sigkill);
      _process = null;
      _emitRunningState(false);

      await _foregroundTaskService.stop();

      return true;
    } catch (error) {
      _logger.pageError('Failed to stop service', channel: LogChannel.server, error: error);
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
