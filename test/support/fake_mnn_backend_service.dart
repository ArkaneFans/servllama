import 'dart:async';

import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/services/engines/mnn_backend_service.dart';

class FakeMnnBackendService extends MnnBackendService {
  List<MnnBackendCapability> capabilities = [
    for (final backend in MnnBackend.values)
      MnnBackendCapability(
        backend: backend,
        compiled: true,
        available: backend != MnnBackend.hexagon,
        status: backend == MnnBackend.hexagon
            ? MnnBackendStatus.runtimeLibrariesMissing
            : MnnBackendStatus.available,
      ),
  ];
  MnnBackend? activeBackend;
  Object? error;
  Completer<void>? pending;
  final changes = StreamController<MnnBackend?>.broadcast();

  @override
  Future<({List<MnnBackendCapability> capabilities, MnnBackend? activeBackend})>
  load() async {
    await pending?.future;
    if (error != null) throw error!;
    return (capabilities: capabilities, activeBackend: activeBackend);
  }

  @override
  Stream<MnnBackend?> get activeBackendChanges => changes.stream;

  Future<void> dispose() => changes.close();
}
