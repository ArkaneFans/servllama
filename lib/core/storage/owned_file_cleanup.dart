import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/logging/app_logger.dart';

enum OwnedFileKind { chatAttachment, speechJob, voiceProfile }

/// A small durable deletion queue for the three application-owned file stores.
/// Enqueue with the record deletion transaction; retry after commit or startup.
/// Model packages already have their own persisted deleting state.
class OwnedFileCleanup {
  OwnedFileCleanup(this.db, this.root);
  final AppDatabase db;
  final Directory root;

  String _folder(OwnedFileKind kind) => switch (kind) {
    OwnedFileKind.chatAttachment => 'chat_attachments',
    OwnedFileKind.speechJob => p.join('speech', 'jobs'),
    OwnedFileKind.voiceProfile => p.join('speech', 'voices'),
  };

  Future<void> enqueue(String path, OwnedFileKind kind) async {
    final absolute = p.normalize(p.absolute(path));
    final folder = p.normalize(p.absolute(p.join(root.path, _folder(kind))));
    if (!p.isWithin(folder, absolute)) return;
    if (kind != OwnedFileKind.chatAttachment && p.dirname(absolute) != folder) {
      return;
    }
    await db.execute(
      'INSERT INTO pending_file_deletions(path,kind) VALUES(?,?) ON CONFLICT(path) DO NOTHING',
      [path, kind.name],
    );
  }

  Future<void> retry() async {
    try {
      final rows = await db.query(
        'SELECT path,kind FROM pending_file_deletions',
      );
      if (rows.isEmpty) return;
      final canonicalRoot = await root.resolveSymbolicLinks();
      for (final row in rows) {
        final storedPath = row.read<String>('path');
        final path = p.normalize(p.absolute(storedPath));
        final kind = OwnedFileKind.values.byName(row.read<String>('kind'));
        final folder = p.join(canonicalRoot, _folder(kind));
        if (!p.isWithin(p.join(root.absolute.path, _folder(kind)), path)) {
          continue;
        }
        if (kind != OwnedFileKind.chatAttachment &&
            p.dirname(path) != p.join(root.absolute.path, _folder(kind))) {
          continue;
        }
        try {
          // Keep reference registration serialized with this final check. File
          // removal is idempotent; a failed acknowledgement retains the intent.
          await db.transaction(() async {
            final references = kind == OwnedFileKind.chatAttachment
                ? await db.query(
                    'SELECT 1 FROM revision_attachments WHERE path=? LIMIT 1',
                    [storedPath],
                  )
                : await db.query(
                    'SELECT 1 FROM ${kind == OwnedFileKind.speechJob ? 'speech_jobs' : 'voice_profiles'} WHERE id=?',
                    [p.basename(path)],
                  );
            if (references.isEmpty) {
              final type = await FileSystemEntity.type(
                path,
                followLinks: false,
              );
              if (type != FileSystemEntityType.notFound) {
                final FileSystemEntity entity =
                    kind == OwnedFileKind.chatAttachment
                    ? File(path)
                    : Directory(path);
                if (type !=
                        (kind == OwnedFileKind.chatAttachment
                            ? FileSystemEntityType.file
                            : FileSystemEntityType.directory) ||
                    !p.isWithin(folder, await entity.resolveSymbolicLinks())) {
                  return;
                }
                await entity.delete(
                  recursive: kind != OwnedFileKind.chatAttachment,
                );
              }
            }
            await db.execute(
              'DELETE FROM pending_file_deletions WHERE path=?',
              [storedPath],
            );
          });
        } on FileSystemException {
          // Locked or unavailable files are retried at the next deletion/start.
        }
      }
    } catch (error) {
      AppLogger.instance.event(
        'storage.cleanup_failed',
        level: LogLevel.warning,
        fields: AppLogger.errorFields(error),
      );
    }
  }
}
