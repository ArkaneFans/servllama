import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/features/speech/models/speech_models.dart';

import 'speech_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Map<String, dynamic> fixtureJson() =>
      jsonDecode(jsonEncode(SpeechHarness.cosyPackage().toJson()))
          as Map<String, dynamic>;

  test(
    'catalog replaces Qwen Base with a pinned multilingual CosyVoice package',
    () async {
      final json =
          jsonDecode(await rootBundle.loadString('assets/speech/catalog.json'))
              as List;
      final packages = json
          .map((j) => SpeechPackage.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      expect(packages.map((p) => p.recipe), [
        SpeechRecipe.sherpaWhisper,
        SpeechRecipe.sherpaVits,
        SpeechRecipe.crispWhisper,
        SpeechRecipe.crispCosyVoiceTts,
      ]);
      final preset = packages.last;
      expect(preset.totalBytes, 786910496);
      expect(preset.files, hasLength(4));
      expect(preset.recipe.kind, AssetKind.tts);
      expect(preset.recipe.canClone, isFalse);
      expect(preset.recipe.synthesisSpeed, isFalse);
      expect(preset.config['languages'], containsAll(['zh', 'en', 'ja', 'ko']));
      expect(preset.license, contains('Apache-2.0'));
      expect(preset.license, contains('CC-BY-4.0'));
      for (final file in preset.files) {
        final url = Uri.parse(file.url!);
        expect(url.scheme, 'https');
        expect(url.host, 'huggingface.co');
        expect(url.pathSegments, [
          'cstr',
          'cosyvoice3-0.5b-2512-GGUF',
          'resolve',
          preset.revision,
          file.path,
        ]);
      }
    },
  );

  test('CrispASR dispatch preserves legacy backends and selects CosyVoice', () {
    expect(SpeechRecipe.crispWhisper.crispBackend, 'whisper');
    expect(SpeechRecipe.crispQwenTts.crispBackend, 'qwen3-tts');
    expect(SpeechRecipe.crispQwenTts.canClone, isTrue);
    expect(SpeechRecipe.crispCosyVoiceTts.crispBackend, 'cosyvoice3-tts');
    expect(SpeechRecipe.sherpaVits.crispBackend, isNull);
    expect(SpeechRecipe.sherpaWhisper.crispBackend, isNull);
  });

  test('CosyVoice requires each native companion before installation', () {
    for (final role in SpeechRecipe.crispCosyVoiceTts.requiredRoles) {
      final json = fixtureJson();
      (json['config'] as Map).remove(role);
      expect(() => SpeechPackage.fromJson(json), throwsFormatException);
    }
    final json = fixtureJson();
    (json['files'] as List).removeLast();
    expect(() => SpeechPackage.fromJson(json), throwsFormatException);
  });

  test('CosyVoice companions keep discoverable names beside the LLM', () {
    final nested = fixtureJson();
    for (final file in nested['files'] as List) {
      file['path'] = 'nested/${file['path']}';
    }
    final config = nested['config'] as Map;
    for (final role in SpeechRecipe.crispCosyVoiceTts.requiredRoles) {
      config[role] = 'nested/${config[role]}';
    }
    expect(() => SpeechPackage.fromJson(nested), returnsNormally);

    final moved = fixtureJson();
    final voices = (moved['files'] as List).last as Map;
    voices['path'] = 'other/cosyvoice3-voices.gguf';
    (moved['config'] as Map)['voices'] = voices['path'];
    expect(() => SpeechPackage.fromJson(moved), throwsFormatException);

    final renamed = fixtureJson();
    (renamed['files'] as List).last['path'] = 'renamed.gguf';
    (renamed['config'] as Map)['voices'] = 'renamed.gguf';
    expect(() => SpeechPackage.fromJson(renamed), throwsFormatException);
  });
}
