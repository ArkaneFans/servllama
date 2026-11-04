import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/services/model_file_browser.dart';
import 'package:servllama/features/server/pages/model_file_picker_page.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

void main() {
  Widget host({
    required bool directoriesOnly,
    required ValueChanged<SelectedModelPath?> onPicked,
  }) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => onPicked(
            await Navigator.push<SelectedModelPath>(
              context,
              MaterialPageRoute(
                builder: (_) => ModelFilePickerPage(
                  rootPath: '/storage',
                  directoriesOnly: directoriesOnly,
                  browser: _Browser(),
                ),
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );

  test(
    'browser filters GGUFs and lists directories first without copying files',
    () async {
      final root = await Directory.systemTemp.createTemp('model_picker_');
      try {
        await Directory('${root.path}/Models').create();
        await File('${root.path}/tiny.GGUF').writeAsString('weights');
        await File('${root.path}/hidden.txt').writeAsString('text');
        final browser = ModelFileBrowser();
        final entries = await browser.list(root.path, directoriesOnly: false);
        expect(entries.map((entry) => entry.name), ['Models', 'tiny.GGUF']);
        expect((await browser.select(entries.last)).path, entries.last.path);
        expect(
          (await browser.list(root.path, directoriesOnly: true)).single.name,
          'Models',
        );
        expect(await root.list().length, 3);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );

  testWidgets('navigates folders and returns the original file path', (
    tester,
  ) async {
    SelectedModelPath? selected;
    await tester.pumpWidget(
      host(directoriesOnly: false, onPicked: (value) => selected = value),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Models'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('上一级目录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Models'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('tiny.gguf'));
    await tester.pumpAndSettle();
    expect(selected!.path, '/storage/Models/tiny.gguf');
    expect(selected!.sizeBytes, 7);
  });

  testWidgets(
    'MNN mode selects a directory without probing for config or weights',
    (tester) async {
      SelectedModelPath? selected;
      await tester.pumpWidget(
        host(directoriesOnly: true, onPicked: (value) => selected = value),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('使用此模型目录'));
      await tester.pumpAndSettle();
      expect(selected!.path, '/storage');
    },
  );
}

class _Browser extends ModelFileBrowser {
  @override
  Future<List<ModelFileEntry>> list(
    String path, {
    required bool directoriesOnly,
  }) async => [
    if (path == '/storage')
      const ModelFileEntry(path: '/storage/Models', isDirectory: true),
    if (path == '/storage/Models' && !directoriesOnly)
      const ModelFileEntry(
        path: '/storage/Models/tiny.gguf',
        isDirectory: false,
      ),
  ];

  @override
  Future<SelectedModelPath> select(ModelFileEntry entry) async =>
      SelectedModelPath(
        path: entry.path,
        name: entry.name,
        sizeBytes: entry.isDirectory ? 0 : 7,
      );
}
