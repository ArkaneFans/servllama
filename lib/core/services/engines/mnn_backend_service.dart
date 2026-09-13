import 'package:mnn_engine/mnn_engine.dart';

class MnnBackendService {
  MnnBackendService({MnnEngine? engine})
    : _engine = engine ?? MnnEngine.instance;

  final MnnEngine _engine;

  Future<({List<MnnBackendCapability> capabilities, MnnBackend? activeBackend})>
  load() async {
    await _engine.initialize();
    final capabilities = await _engine.getBackendCapabilities();
    final snapshot = await _engine.getSnapshot();
    return (
      capabilities: capabilities,
      activeBackend: snapshot.activeModel?.backend,
    );
  }

  Stream<MnnBackend?> get activeBackendChanges => _engine.events
      .map((event) => event.snapshot.activeModel?.backend)
      .distinct();
}
