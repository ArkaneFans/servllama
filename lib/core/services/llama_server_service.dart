import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/services/foreground_task_service.dart';
import 'package:servllama/core/services/native_library_dir_service.dart';
import 'package:servllama/core/storage/kv_storage.dart';

class LlamaServerService {
  static final LlamaServerService _instance = LlamaServerService._internal();

  factory LlamaServerService() => _instance;

  LlamaServerService._internal();

  static const String _binaryFileName = 'libllama-server.so';
  static const String _manifestAssetPath =
      'assets/bin/llama_server_manifest.json';

  // Leftovers from the removed assets-based installer; kept only for cleanup.
  static const String _legacyBinaryDirectoryName = 'bin';
  static const String _legacyInstalledVersionPrefKey =
      'server.llama_server_installed_version';

  final KvStorage _kvStorage = KvStorage.instance;
  final AppLogger _logger = AppLogger.instance;
  final NativeLibraryDirService _nativeLibraryDirService =
      NativeLibraryDirService();
  final StreamController<bool> _runningStateController =
      StreamController<bool>.broadcast();
  final AppL10nService _l10nService = AppL10nService.instance;
  final ForegroundTaskService _foregroundTaskService = ForegroundTaskService();
  bool _foregroundTaskInitialized = false;
  bool _legacyCleanupStarted = false;

  Process? _process;
  bool _lastRunningState = false;

  Stream<String> get logStream => _logger
      .streamFor(LogChannel.server)
      .map((entry) => entry.formattedMessage);
  Stream<bool> get runningStateStream => _runningStateController.stream;

  bool get isRunning => _process != null;

  /// Version of the bundled llama-server build, as declared in the
  /// manifest asset shipped alongside the jniLibs binaries.
  Future<String> loadBundledVersion() async {
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

  void initForegroundTask() {
    if (_foregroundTaskInitialized) return;
    _foregroundTaskService.init();
    _foregroundTaskInitialized = true;
  }

  Future<bool> startServer({List<String>? args}) async {
    if (_process != null) {
      _logger.warning('Server is already running', channel: LogChannel.server, inMemory: true);
      return false;
    }

    unawaited(_cleanupLegacyInstall());

    try {
      final nativeLibraryDir =
          await _nativeLibraryDirService.getNativeLibraryDir();
      final binaryPath = '$nativeLibraryDir/$_binaryFileName';
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
          'LD_LIBRARY_PATH': nativeLibraryDir,
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

  Future<void> _cleanupLegacyInstall() async {
    if (_legacyCleanupStarted) {
      return;
    }
    _legacyCleanupStarted = true;

    try {
      final supportDir = await getApplicationSupportDirectory();
      final legacyDir = Directory(
        '${supportDir.path}/$_legacyBinaryDirectoryName',
      );
      if (await legacyDir.exists()) {
        await legacyDir.delete(recursive: true);
        _logger.info(
          'Removed legacy llama-server install directory',
          channel: LogChannel.server,
          inMemory: true,
        );
      }
      await _kvStorage.remove(_legacyInstalledVersionPrefKey);
    } catch (error) {
      _logger.warning(
        'Failed to clean up legacy llama-server install',
        channel: LogChannel.server,
        inMemory: true,
        error: error,
      );
    }
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