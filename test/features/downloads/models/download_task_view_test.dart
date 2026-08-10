import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/downloads/models/download_task.dart';
import 'package:servllama/features/downloads/models/download_task_view.dart';

void main() {
  test('keeps the native import stage in the active task list', () {
    expect(DownloadStatus.downloaded.isActive, isTrue);
    expect(DownloadStatus.downloaded.canPause, isFalse);
    expect(DownloadStatus.downloaded.canCancel, isFalse);
  });

  test('does not invent a percentage while any file size is unknown', () {
    final view = DownloadTaskView(
      _task(
        files: <DownloadFileRecord>[
          DownloadFileRecord(
            remotePath: 'config.json',
            fileName: 'config.json',
            totalBytes: 100,
            receivedBytes: 100,
            completed: true,
          ),
          DownloadFileRecord(
            remotePath: 'llm.mnn.weight',
            fileName: 'llm.mnn.weight',
            totalBytes: 0,
            receivedBytes: 250,
          ),
        ],
      ),
      bytesPerSecond: 50,
    );

    expect(view.hasKnownTotal, isFalse);
    expect(view.receivedBytes, 350);
    expect(view.progress, 0);
    expect(view.remaining, isNull);
  });
}

DownloadTaskRecord _task({required List<DownloadFileRecord> files}) {
  return DownloadTaskRecord(
    id: 'task',
    engineValue: 'mnn',
    sourceValue: 'modelscope',
    repoId: 'MNN/model',
    revision: 'master',
    modelName: 'model',
    files: files,
    statusValue: DownloadStatus.running.name,
    createdAt: DateTime(2026),
    stagingDirPath: '/tmp/task',
  );
}
