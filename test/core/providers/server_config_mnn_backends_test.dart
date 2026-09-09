import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mnn_engine/mnn_engine.dart';
import 'package:servllama/core/providers/server_config_provider.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/core/storage/server_prefs_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_mnn_backend_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeMnnBackendService service;
  late KvStorage storage;
  late ServerConfigProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = KvStorage();
    service = FakeMnnBackendService();
    provider = ServerConfigProvider(
      kvStorage: storage,
      mnnBackendService: service,
    );
  });
  tearDown(() async {
    provider.dispose();
    await service.dispose();
  });

  test(
    'persists an available backend and rejects unavailable selection',
    () async {
      await provider.load();
      await provider.loadMnnBackends();
      await provider.updateMnnBackend(MnnBackend.vulkan);
      expect(await storage.getString(ServerPrefsKeys.mnnBackend), 'vulkan');
      await provider.updateMnnBackend(MnnBackend.hexagon);
      expect(provider.mnnBackend, MnnBackend.vulkan);
      expect(await storage.getString(ServerPrefsKeys.mnnBackend), 'vulkan');
      await provider.resetToDefaults();
      expect(provider.mnnBackend, MnnBackend.cpu);
      expect(await storage.getString(ServerPrefsKeys.mnnBackend), 'cpu');
    },
  );

  test(
    'keeps the running backend separate from the next launch selection',
    () async {
      service.activeBackend = MnnBackend.cpu;
      await provider.loadMnnBackends();
      await provider.updateMnnBackend(MnnBackend.opencl);
      expect(provider.activeMnnBackend, MnnBackend.cpu);
      service.changes.add(MnnBackend.opencl);
      await Future<void>.delayed(Duration.zero);
      expect(provider.activeMnnBackend, MnnBackend.opencl);
      service.changes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(provider.activeMnnBackend, isNull);
      expect(provider.mnnBackend, MnnBackend.opencl);
    },
  );

  test(
    'does not silently replace a saved unavailable accelerator with CPU',
    () async {
      await storage.setString(ServerPrefsKeys.mnnBackend, 'hexagon');
      await provider.load();
      await provider.loadMnnBackends();
      expect(provider.mnnBackend, MnnBackend.hexagon);
      await provider.updateMnnBackend(MnnBackend.cpu);
      expect(await storage.getString(ServerPrefsKeys.mnnBackend), 'cpu');
    },
  );

  test(
    'a failed probe can be retried and does not prevent choosing CPU',
    () async {
      service.error = StateError('driver probe failed');
      await provider.loadMnnBackends();
      expect(provider.mnnBackendError, contains('driver probe failed'));
      expect(provider.loadingMnnBackends, isFalse);
      await provider.updateMnnBackend(MnnBackend.opencl);
      expect(provider.mnnBackend, MnnBackend.cpu);
      service.error = null;
      await provider.loadMnnBackends();
      expect(provider.mnnBackendError, isNull);
      await provider.updateMnnBackend(MnnBackend.opencl);
      expect(provider.mnnBackend, MnnBackend.opencl);
    },
  );

  test(
    'finishing a probe after page disposal does not notify listeners',
    () async {
      final pendingService = FakeMnnBackendService()
        ..pending = Completer<void>();
      final pendingProvider = ServerConfigProvider(
        kvStorage: storage,
        mnnBackendService: pendingService,
      );
      var notifications = 0;
      pendingProvider.addListener(() => notifications++);
      final loading = pendingProvider.loadMnnBackends();
      pendingProvider.dispose();
      final beforeCompletion = notifications;
      pendingService.pending!.complete();
      await loading;
      expect(notifications, beforeCompletion);
      await pendingService.dispose();
    },
  );
}
