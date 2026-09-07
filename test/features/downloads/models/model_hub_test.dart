import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/pages/hub_repo_page.dart';

void main() {
  group('HubRepoFile.isMmproj', () {
    test('treats names that contain mmproj as projector files', () {
      expect(
        const HubRepoFile(
          path: 'Qwen3.5-0.8B-mmproj-f16.gguf',
          sizeBytes: 10,
        ).isMmproj,
        isTrue,
      );
      expect(
        const HubRepoFile(path: 'mmproj-f32.gguf', sizeBytes: 10).isMmproj,
        isTrue,
      );
      expect(
        const HubRepoFile(
          path: 'Qwen3.5-0.8B-Q4_K_M.gguf',
          sizeBytes: 10,
        ).isMmproj,
        isFalse,
      );
    });
  });

  group('HubRepoDetail', () {
    const q4 = HubRepoFile(path: 'Qwen-Q4_K_M.gguf', sizeBytes: 40);
    const q8 = HubRepoFile(path: 'Qwen-Q8_0.gguf', sizeBytes: 80);
    const firstMmproj = HubRepoFile(
      path: 'Qwen3.5-0.8B-mmproj-f16.gguf',
      sizeBytes: 12,
    );
    const secondMmproj = HubRepoFile(path: 'mmproj-f32.gguf', sizeBytes: 24);

    final detail = HubRepoDetail(
      summary: const HubRepoSummary(
        source: ModelHubSource.huggingFace,
        format: HubModelFormat.gguf,
        repoId: 'owner/qwen',
        owner: 'owner',
        name: 'qwen',
      ),
      files: const <HubRepoFile>[q8, firstMmproj, q4, secondMmproj],
    );

    test(
      'lists projector files in repository order and keeps the first one',
      () {
        expect(detail.hasMmproj, isTrue);
        expect(detail.mmprojFiles, <HubRepoFile>[firstMmproj, secondMmproj]);
        expect(detail.mmprojFile, firstMmproj);
        expect(detail.ggufFiles, <HubRepoFile>[q8, q4]);
      },
    );
  });

  group('ggufDownloadFiles', () {
    const quant = HubRepoFile(path: 'Qwen-Q4_K_M.gguf', sizeBytes: 40);
    const mmproj = HubRepoFile(
      path: 'Qwen3.5-0.8B-mmproj-f16.gguf',
      sizeBytes: 12,
    );

    test('includes the selected projector when vision is enabled', () {
      expect(
        ggufDownloadFiles(
          quantFile: quant,
          visionEnabled: true,
          mmprojFile: mmproj,
        ),
        <HubRepoFile>[quant, mmproj],
      );
    });

    test('downloads only the quant when vision is off', () {
      expect(
        ggufDownloadFiles(
          quantFile: quant,
          visionEnabled: false,
          mmprojFile: mmproj,
        ),
        <HubRepoFile>[quant],
      );
    });

    test('downloads only the quant when no projector is selected', () {
      expect(
        ggufDownloadFiles(quantFile: quant, visionEnabled: true),
        <HubRepoFile>[quant],
      );
    });
  });
}
