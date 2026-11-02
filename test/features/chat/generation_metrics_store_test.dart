import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/models/generation_metrics.dart';
import 'package:servllama/features/chat/repositories/chat_record_store.dart';

void main() {
  test(
    'schema 1 upgrades in place preserving old messages with unknown stats',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'metrics-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      var db = AppDatabase.at(directory);
      var store = ChatRecordStore(db);
      final date = DateTime(2026);
      await store.saveSession(
        ChatSessionRecord(
          id: 's',
          title: 'History',
          createdAt: date,
          updatedAt: date,
        ),
      );
      await store.saveMessage(
        ChatMessageRecord(
          id: 'm',
          sessionId: 's',
          role: ChatRole.assistant,
          content: 'Existing response',
          createdAt: date,
        ),
      );
      // Precisely restore the previous release layout/version before opening the
      // new application: v1 differed only by this nullable revision column.
      await db.customStatement(
        'ALTER TABLE message_revisions DROP COLUMN generation_metrics',
      );
      await db.customStatement('PRAGMA user_version=1');
      await db.close();
      db = AppDatabase.at(directory);
      store = ChatRecordStore(db);
      try {
        final message = (await store.message('m'))!;
        expect(message.content, 'Existing response');
        expect(message.generationMetrics, isNull);
        expect(
          (await db.query(
            'PRAGMA user_version',
          )).single.read<int>('user_version'),
          2,
        );
        expect(await db.query('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        await db.close();
      }
    },
  );

  test(
    'native/estimated stats and identity persist per revision across reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'metrics-history-',
      );
      addTearDown(() => directory.delete(recursive: true));
      var db = AppDatabase.at(directory);
      var store = ChatRecordStore(db);
      final date = DateTime(2026);
      final original =
          const GenerationMetrics(
                inputTokens: 100,
                outputTokens: 11,
                cachedInputTokens: 0,
              )
              .withEstimates(
                firstTokenMilliseconds: 200,
                outputMilliseconds: 500,
              )
              .withIdentity(
                modelId: 'model',
                connectionId: 'c',
                contextKey: 'hash',
              );
      await store.saveSession(
        ChatSessionRecord(
          id: 's',
          title: 'History',
          createdAt: date,
          updatedAt: date,
        ),
      );
      await store.saveMessage(
        ChatMessageRecord(
          id: 'm',
          sessionId: 's',
          role: ChatRole.assistant,
          content: 'Original',
          createdAt: date,
          generationMetrics: original,
          versionIds: ['v1'],
        ),
      );
      await store.saveVersion(
        ChatMessageVersionRecord(
          id: 'v2',
          messageId: 'm',
          content: 'Edited',
          createdAt: date,
        ),
      );
      await store.selectVersion('m', 'v2');
      await db.close();
      db = AppDatabase.at(directory);
      store = ChatRecordStore(db);
      try {
        expect((await store.message('m'))!.generationMetrics, isNull);
        final version = (await store.version('v1'))!;
        expect(version.generationMetrics, original);
        expect(version.generationMetrics!.cachedInputTokens, 0);
        expect(version.generationMetrics!.decodeIsEstimated, isTrue);
        expect(version.generationMetrics!.contextKey, 'hash');
        await store.selectVersion('m', 'v1');
        final message = (await store.message('m'))!;
        expect(message.generationMetrics, original);
        expect(
          message
              .withVersion((await store.version('v2'))!, 1)
              .generationMetrics,
          isNull,
        );
      } finally {
        await db.close();
      }
    },
  );
}
