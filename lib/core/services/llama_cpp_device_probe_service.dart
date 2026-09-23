import 'dart:io';

import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/llama_cpp_backend.dart';
import 'package:servllama/core/services/llama_server_environment.dart';
import 'package:servllama/core/services/native_library_dir_service.dart';

class LlamaCppDeviceProbeService {
  LlamaCppDeviceProbeService({
    NativeLibraryDirService? nativeLibraryDirService,
    AppLogger? logger,
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments,
      Map<String, String> environment,
    )?
    runner,
    LlamaCppDeviceProbeResult Function()? resultOverride,
  }) : _nativeLibraryDirService =
           nativeLibraryDirService ?? NativeLibraryDirService(),
       _logger = logger ?? AppLogger.instance,
       _runner = runner ?? _runProcess,
       _resultOverride = resultOverride;

  static const String _binaryFileName = 'libllama-server.so';
  static const Duration _timeout = Duration(seconds: 20);

  final NativeLibraryDirService _nativeLibraryDirService;
  final AppLogger _logger;
  final Future<ProcessResult> Function(
    String executable,
    List<String> arguments,
    Map<String, String> environment,
  )
  _runner;
  final LlamaCppDeviceProbeResult Function()? _resultOverride;

  LlamaCppDeviceProbeResult? _cached;

  LlamaCppDeviceProbeResult? get cached => _cached;

  Future<LlamaCppDeviceProbeResult> probe({bool force = false}) async {
    final cached = _cached;
    if (!force && cached != null) {
      return cached;
    }
    final override = _resultOverride;
    if (override != null) {
      _cached = override();
      return _cached!;
    }
    try {
      final nativeLibraryDir = await _nativeLibraryDirService
          .getNativeLibraryDir();
      final binaryPath = '$nativeLibraryDir/$_binaryFileName';
      final result = await _runner(
        binaryPath,
        const <String>['--list-devices'],
        llamaServerLibraryEnvironment(nativeLibraryDir),
      ).timeout(_timeout);
      final output = '${result.stdout}\n${result.stderr}';
      if (result.exitCode != 0) {
        _logger.warning(
          'llama-server --list-devices exited ${result.exitCode}',
          channel: LogChannel.engine,
          inMemory: true,
        );
        final parsed = parseLlamaCppListDevices(output);
        _cached = LlamaCppDeviceProbeResult(
          openclDeviceName: parsed.openclDeviceName,
          hexagonDeviceName: parsed.hexagonDeviceName,
          rawOutput: output,
          error: 'exit ${result.exitCode}',
        );
        return _cached!;
      }
      _cached = parseLlamaCppListDevices(output);
      return _cached!;
    } catch (error) {
      _logger.warning(
        'llama-server device probe failed: $error',
        channel: LogChannel.engine,
        inMemory: true,
        error: error,
      );
      _cached = LlamaCppDeviceProbeResult(error: error.toString());
      return _cached!;
    }
  }

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments,
    Map<String, String> environment,
  ) {
    return Process.run(
      executable,
      arguments,
      environment: environment,
      runInShell: false,
    );
  }
}
