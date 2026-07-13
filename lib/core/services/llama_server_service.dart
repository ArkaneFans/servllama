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

  static const Duration _gracefulStopTimeout = Duration(seconds: 3);

  Process? _process;
  bool _isStarting = false;
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
    if (_process != null || _isStarting) {
      _logger.warning('Server is already running', channel: LogChannel.server, inMemory: true);
      return false;
    }
    _isStarting = true;

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
          // Vendor dirs are appended so the backends can dlopen Qualcomm
          // public libraries (libcdsprpc.so for Hexagon, libOpenCL.so for
          // OpenCL) — the spawned process does not inherit the app
          // classloader namespace that normally exposes them.
          'LD_LIBRARY_PATH': '$nativeLibraryDir:/vendor/lib64:/odm/lib64',
          // Required by FastRPC to locate the libggml-htp-vNN.so NPU-side
          // libraries when the Hexagon backend is used.
          'ADSP_LIBRARY_PATH': nativeLibraryDir,
        },
      );

      _process = process;
      _emitRunningState(true);

      await _foregroundTaskService.start(
        notificationTitle: _l10nService.current.serverForegroundNotificationTitle,
        notificationText: _l10nService.current.serverForegroundNotificationText,
      );

      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            (data) => _handleProcessOutput(data, isError: false),
            onError: (Object error) => _logger.warning(
              'Failed to read server stdout',
              channel: LogChannel.server,
              inMemory: true,
              error: error,
            ),
          );
      process.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen(
            (data) => _handleProcessOutput(data, isError: true),
            onError: (Object error) => _logger.warning(
              'Failed to read server stderr',
              channel: LogChannel.server,
              inMemory: true,
              error: error,
            ),
          );
      process.exitCode.then((code) async {
        // A stale handler from a previous run must not touch the state of a
        // server that was restarted in the meantime.
        if (_process != process) {
          return;
        }
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
    } finally {
      _isStarting = false;
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

  void _handleProcessOutput(String data, {required bool isError}) {
    final lines = data.split('\n');
    for (final line in lines) {
      final message = line.trim();
      if (message.isEmpty) {
        continue;
      }
      if (isError) {
        _logger.warning(message, channel: LogChannel.server, inMemory: true);
      } else {
        _logger.info(message, channel: LogChannel.server, inMemory: true);
      }
    }
  }

  Future<bool> stopServer() async {
    final process = _process;
    if (process == null) {
      _logger.warning('Server is not running', channel: LogChannel.server, inMemory: true);
      return false;
    }

    _logger.info('Stopping service...', channel: LogChannel.server, inMemory: true);
    try {
      // Ask for a graceful shutdown first; escalate to SIGKILL if the server
      // does not exit in time. State cleanup (clearing _process, emitting
      // running=false, stopping the foreground service) is owned by the
      // guarded exitCode handler registered in startServer.
      if (!process.kill(ProcessSignal.sigterm)) {
        _logger.warning(
          'Failed to signal server process (SIGTERM)',
          channel: LogChannel.server,
          inMemory: true,
        );
      }
      try {
        await process.exitCode.timeout(_gracefulStopTimeout);
      } on TimeoutException {
        _logger.warning(
          'Server did not exit gracefully, sending SIGKILL',
          channel: LogChannel.server,
          inMemory: true,
        );
        process.kill(ProcessSignal.sigkill);
        await process.exitCode;
      }
      return true;
    } catch (error) {
      _logger.error('Failed to stop service', channel: LogChannel.server, inMemory: true, error: error);
      // The process state is unknown; force-clear so the UI is not stuck on
      // a phantom "running" state.
      if (_process == process) {
        _process = null;
        _emitRunningState(false);
        await _foregroundTaskService.stop();
      }
      return false;
    }
  }

  void _emitRunningState(bool isRunning) {
    if (_lastRunningState == isRunning) {
      return;
    }
    _lastRunningState = isRunning;
    _runningStateController.add(isRunning);
  }

  /// Releases the running-state stream. Only meaningful in tests — the
  /// production instance is an app-lifetime singleton.
  void dispose() {
    _runningStateController.close();
  }
}