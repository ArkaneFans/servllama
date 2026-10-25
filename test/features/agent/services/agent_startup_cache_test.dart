import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';

void main() {
  test('skill warmup and first route read share one snapshot', () async {
    final db = AppDatabase.memory();
    final repository = _DelayedSkills(db);
    final tools = AgentToolService(
      repository,
      Directory.systemTemp,
      logger: AppLogger(),
    );
    final first = tools.ensureSkillsLoaded();
    final route = tools.ensureSkillsLoaded();
    expect(identical(first, route), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(repository.reads, 1);
    repository.pending.complete();
    await Future.wait([first, route]);
    await tools.ensureSkillsLoaded();
    expect(repository.reads, 1);
    expect(tools.cachedSkills!.single.name, 'old');
    tools.dispose();
    await db.close();
  });

  test(
    'refresh after a mutation does not reuse an older pending prefetch',
    () async {
      final db = AppDatabase.memory();
      final repository = _DelayedSkills(db);
      final tools = AgentToolService(
        repository,
        Directory.systemTemp,
        logger: AppLogger(),
      );
      final initial = tools.ensureSkillsLoaded();
      await Future<void>.delayed(Duration.zero);
      repository.current = _record('new');
      final refresh = tools.loadSkills();
      expect(repository.reads, 1);
      repository.pending.complete();
      await Future.wait([initial, refresh]);
      expect(repository.reads, 2);
      expect(tools.cachedSkills!.single.name, 'new');
      tools.dispose();
      await db.close();
    },
  );
}

SkillRecord _record(String name) => SkillRecord(
  id: 'skill',
  name: name,
  path: 'owned',
  hash: 'hash',
  description: 'fixture',
);

class _DelayedSkills extends AgentRepository {
  _DelayedSkills(super.db);
  final pending = Completer<void>();
  int reads = 0;
  SkillRecord current = _record('old');
  @override
  Future<List<SkillRecord>> skills() async {
    final snapshot = current;
    if (++reads == 1) await pending.future;
    return [snapshot];
  }
}
