import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/downloads/services/download_settings_store.dart';
import 'package:servllama/features/downloads/services/hugging_face_route_resolver.dart';
import 'package:servllama/features/downloads/services/model_download_service.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/services/speech_model_service.dart';

import 'speech_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'speech retry reads the selected route and keeps pinned metadata',
    () async {
      final harness = SpeechHarness();
      await harness.initialize();
      const channel = MethodChannel(
        'com.arkanefans.servllama/download_environment',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => 1 << 30);
      final settings = DownloadSettingsStore(kvStorage: KvStorage());
      await settings.saveHuggingFaceRoute(HuggingFaceRoute.mirror);
      final requests = <Uri>[];
      var fail = true;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add(request.uri);
            final bytes =
                SpeechHarness.fixtureFiles[request.uri.pathSegments.last]!;
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: fail ? 503 : 200,
                data: ResponseBody.fromBytes(bytes, fail ? 503 : 200),
              ),
            );
          },
        ),
      );
      final service = SpeechModelService(
        harness.service.models.models,
        harness.service.models.repository,
        harness.service.root,
        downloader: ModelDownloadService(dio: dio),
        downloadSettings: settings,
        logger: harness.logger,
      );
      addTearDown(() async {
        service.dispose();
        dio.close();
        messenger.setMockMethodCallHandler(channel, null);
        await harness.close();
      });
      final json = SpeechHarness.package().toJson();
      for (final file in json['files'] as List) {
        file['url'] =
            'https://huggingface.co/test/voice/resolve/pinned/${file['path']}';
      }
      final asset = await service.createAsset(SpeechPackage.fromJson(json));
      await expectLater(
        service.resume(asset),
        throwsA(isA<DownloadException>()),
      );
      expect(requests.single.host, 'hf-mirror.com');
      expect((await service.models.asset(asset.id))!.state, 'paused');

      await settings.saveHuggingFaceRoute(HuggingFaceRoute.official);
      fail = false;
      await service.resume(asset);
      expect(
        requests.skip(1).map((uri) => uri.host),
        everyElement('huggingface.co'),
      );
      expect(
        requests.map((uri) => uri.path),
        everyElement(startsWith('/test/voice/resolve/pinned/')),
      );
      final saved = (await service.models.asset(asset.id))!;
      expect(saved.isReady, isTrue);
      expect(saved.manifest, asset.manifest);
    },
  );

  test('auto routes package files; unrelated origins remain unchanged', () async {
    final probes = <String>[];
    final dio = Dio();
    addTearDown(dio.close);
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          probes.add(request.uri.host);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: request.uri.host == 'hf-mirror.com' ? 200 : 503,
            ),
          );
        },
      ),
    );
    final resolver = HuggingFaceRouteResolver(dio: dio);
    const source =
        'https://huggingface.co/a/b/resolve/abc/path%20one/model.onnx?download=true';
    expect(
      await resolver.resolveFileUrl(source, HuggingFaceRoute.auto),
      source.replaceFirst('huggingface.co', 'hf-mirror.com'),
    );
    expect(probes, containsAll(['huggingface.co', 'hf-mirror.com']));
    const external = 'https://models.example/a/model.onnx?download=true';
    expect(
      await resolver.resolveFileUrl(external, HuggingFaceRoute.mirror),
      external,
    );
    expect(
      await resolver.resolveFileUrl(
        'https://huggingface.co:8443/model',
        HuggingFaceRoute.mirror,
      ),
      'https://huggingface.co:8443/model',
    );
    expect(probes, hasLength(2));
  });
}
