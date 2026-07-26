import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/features/mnn_test/models/mnn_api_test_result.dart';
import 'package:servllama/features/mnn_test/services/mnn_api_test_client.dart';
import 'package:servllama/features/mnn_test/services/mnn_tool_test_flow_runner.dart';

class MnnTestController extends ChangeNotifier {
  MnnTestController({MnnEngine? engine, MnnApiTestClient? apiClient})
    : _engine = engine ?? MnnEngine.instance,
      _apiClient = apiClient ?? MnnApiTestClient() {
    _toolFlowRunner = MnnToolTestFlowRunner(apiClient: _apiClient);
  }

  final MnnEngine _engine;
  final MnnApiTestClient _apiClient;
  late final MnnToolTestFlowRunner _toolFlowRunner;
  StreamSubscription<MnnRuntimeEvent>? _eventSubscription;
  StreamSubscription<MnnLogEntry>? _logSubscription;

  MnnEngineInfo? engineInfo;
  MnnRuntimeSnapshot? snapshot;
  List<MnnModelInfo> models = const <MnnModelInfo>[];
  final List<MnnLogEntry> logs = <MnnLogEntry>[];
  MnnApiTestResult? apiResult;
  List<MnnApiTestStep> toolFlowSteps = const <MnnApiTestStep>[];
  String streamingOutput = '';
  String? error;
  bool initializing = true;
  bool operationRunning = false;
  bool streamRunning = false;
  bool toolFlowRunning = false;
  MnnPortCheckResult? portCheck;
  MnnServerBindMode bindMode = MnnServerBindMode.loopback;

  void setBindMode(MnnServerBindMode value) {
    if (snapshot?.server?.running == true || bindMode == value) return;
    bindMode = value;
    portCheck = null;
    notifyListeners();
  }

  String generateApiKey() {
    final random = Random.secure();
    const alphabet =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List<String>.generate(
      32,
      (_) => alphabet[random.nextInt(alphabet.length)],
      growable: false,
    ).join();
  }

  Future<void> initialize() async {
    _eventSubscription ??= _engine.events.listen(
      _handleRuntimeEvent,
      onError: (Object eventError) => _setError(eventError.toString()),
    );
    _logSubscription ??= _engine.logs.listen(
      _handleLogEntry,
      onError: (Object logError) => _setError(logError.toString()),
    );
    try {
      engineInfo = await _engine.initialize();
      snapshot = await _engine.getSnapshot();
      logs
        ..clear()
        ..addAll(await _engine.getLogSnapshot());
      await refreshModels(notify: false);
    } catch (exception) {
      error = exception.toString();
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshModels({bool notify = true}) async {
    models = await _engine.listImportedModels();
    if (notify) notifyListeners();
  }

  Future<void> refreshRuntime() => _run(() async {
    snapshot = await _engine.getSnapshot();
    await refreshModels(notify: false);
  });

  Future<void> importModel() => _run(() async {
    await _engine.importModelDirectory();
    await refreshModels(notify: false);
  });

  Future<void> deleteModel(String modelId) => _run(() async {
    await _engine.deleteImportedModel(modelId);
    await refreshModels(notify: false);
  });

  Future<void> loadModel(String modelId) => _run(() async {
    await _engine.loadModel(modelId);
    snapshot = await _engine.getSnapshot();
    await refreshModels(notify: false);
  });

  Future<void> unloadModel() => _run(() async {
    await _engine.unloadModel();
    snapshot = await _engine.getSnapshot();
    await refreshModels(notify: false);
  });

  Future<void> checkPort(int port) => _run(() async {
    portCheck = await _engine.checkPort(bindMode: bindMode, port: port);
  });

  Future<void> startServer({required int port, String? apiKey}) => _run(
    () async {
      await _engine.startServer(bindMode: bindMode, port: port, apiKey: apiKey);
      snapshot = await _engine.getSnapshot();
      final server = snapshot?.server;
      if (server != null) {
        apiResult = await _apiClient.getJson(
          baseUrl: server.localBaseUrl,
          path: '/health',
          apiKey: apiKey,
        );
      }
    },
  );

  Future<void> stopServer() => _run(() async {
    await _engine.stopServer();
    snapshot = await _engine.getSnapshot();
  });

  Future<void> testHealth(String? apiKey) => _testJson('/health', apiKey);
  Future<void> testModels(String? apiKey) => _testJson('/v1/models', apiKey);

  Future<void> testChat({
    required String prompt,
    String? apiKey,
    String? systemPrompt,
    double? temperature,
    double? topP,
    int maxTokens = 512,
  }) async {
    final server = snapshot?.server;
    if (server == null) return _setError('MNN Server is not running.');
    await _run(() async {
      apiResult = await _apiClient.chat(
        baseUrl: server.localBaseUrl,
        prompt: prompt,
        model: snapshot?.activeModel?.modelId,
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        temperature: temperature,
        topP: topP,
        maxTokens: maxTokens,
      );
    });
  }

  Future<void> testStream({
    required String prompt,
    String? apiKey,
    String? systemPrompt,
    double? temperature,
    double? topP,
    int maxTokens = 512,
  }) async {
    final server = snapshot?.server;
    if (server == null) return _setError('MNN Server is not running.');
    if (streamRunning) return;
    streamRunning = true;
    streamingOutput = '';
    apiResult = null;
    error = null;
    notifyListeners();
    try {
      apiResult = await _apiClient.streamChat(
        baseUrl: server.localBaseUrl,
        prompt: prompt,
        model: snapshot?.activeModel?.modelId,
        apiKey: apiKey,
        systemPrompt: systemPrompt,
        temperature: temperature,
        topP: topP,
        maxTokens: maxTokens,
        onChunk: (chunk) {
          streamingOutput += chunk;
          notifyListeners();
        },
      );
    } catch (exception) {
      error = exception.toString();
    } finally {
      streamRunning = false;
      notifyListeners();
    }
  }

  Future<void> testToolFlow({String? apiKey, int maxTokens = 512}) async {
    final server = snapshot?.server;
    if (server == null) return _setError('MNN Server is not running.');
    if (toolFlowRunning || operationRunning) return;
    toolFlowRunning = true;
    toolFlowSteps = const <MnnApiTestStep>[];
    apiResult = null;
    error = null;
    notifyListeners();
    try {
      await _run(() async {
        apiResult = await _toolFlowRunner.run(
          baseUrl: server.localBaseUrl,
          model: snapshot?.activeModel?.modelId,
          apiKey: apiKey,
          maxTokens: maxTokens,
          onProgress: (steps) {
            toolFlowSteps = steps;
            notifyListeners();
          },
        );
      });
    } finally {
      toolFlowRunning = false;
      notifyListeners();
    }
  }

  Future<void> testMultimodal({String? apiKey, int maxTokens = 512}) async {
    final server = snapshot?.server;
    if (server == null) return _setError('MNN Server is not running.');
    if (streamRunning || operationRunning) return;
    streamRunning = true;
    streamingOutput = '';
    apiResult = null;
    error = null;
    notifyListeners();
    try {
      await _run(() async {
        final data = await rootBundle.load('assets/mnn_test/apple.jpg');
        apiResult = await _apiClient.streamMultimodal(
          baseUrl: server.localBaseUrl,
          imageBytes: data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          ),
          model: snapshot?.activeModel?.modelId,
          apiKey: apiKey,
          maxTokens: maxTokens,
          onChunk: (chunk) {
            streamingOutput += chunk;
            notifyListeners();
          },
        );
      });
    } finally {
      streamRunning = false;
      notifyListeners();
    }
  }

  Future<void> cancelStream() async {
    _apiClient.cancelStream();
    await _engine.cancelGeneration();
    streamRunning = false;
    notifyListeners();
  }

  Future<void> clearLogs() async {
    await _engine.clearLogs();
    logs.clear();
    notifyListeners();
  }

  Future<void> _testJson(String path, String? apiKey) async {
    final server = snapshot?.server;
    if (server == null) return _setError('MNN Server is not running.');
    await _run(() async {
      apiResult = await _apiClient.getJson(
        baseUrl: server.localBaseUrl,
        path: path,
        apiKey: apiKey,
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (operationRunning) return;
    operationRunning = true;
    error = null;
    notifyListeners();
    try {
      await action();
    } catch (exception) {
      error = exception.toString();
    } finally {
      operationRunning = false;
      notifyListeners();
    }
  }

  void _handleRuntimeEvent(MnnRuntimeEvent event) {
    if (snapshot == null || event.snapshot.revision >= snapshot!.revision) {
      snapshot = event.snapshot;
      notifyListeners();
    }
  }

  void _handleLogEntry(MnnLogEntry entry) {
    logs.add(entry);
    if (logs.length > 1000) logs.removeRange(0, logs.length - 1000);
    notifyListeners();
  }

  void _setError(String message) {
    error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _logSubscription?.cancel();
    _apiClient.close();
    super.dispose();
  }
}
