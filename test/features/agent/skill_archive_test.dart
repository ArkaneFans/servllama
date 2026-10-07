import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/skill_service.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late SkillService skills;
  late AppLogger logger;
  setUp(() async {
    db = AppDatabase.memory();
    root = await Directory.systemTemp.createTemp('skill-archive-');
    logger = AppLogger();
    skills = SkillService(AgentRepository(db), root, logger: logger);
  });
  tearDown(() async {
    await db.close();
    logger.dispose();
    await root.delete(recursive: true);
  });
  Future<File> zip(List<ArchiveFile> files) async {
    final a = Archive();
    for (final file in files) {
      a.add(file);
    }
    return File('${root.path}/skill.zip').writeAsBytes(ZipEncoder().encode(a));
  }

  test(
    'static skill is imported once and changed content requires reimport',
    () async {
      final source = await zip([
        ArchiveFile.string(
          'example/SKILL.md',
          '---\nname: example\ndescription: static skill\n---\nRead references/guide.md.',
        ),
        ArchiveFile.string('example/references/guide.md', 'facts'),
        ArchiveFile.string(
          'example/scripts/example.py',
          'print("never execute")',
        ),
      ]);
      final skill = await skills.importPackage(source);
      expect(skill.hasScripts, isTrue);
      expect(
        await skills.read(skill, relativePath: 'references/guide.md'),
        'facts',
      );
      await File('${skill.path}/references/guide.md').writeAsString('modified');
      await expectLater(skills.read(skill), throwsFormatException);
      final events = logger.entriesFor(LogChannel.agent);
      expect(
        events.where(
          (e) => e.message.startsWith('agent.skill.import_completed'),
        ),
        hasLength(1),
      );
      expect(
        events.where((e) => e.message.startsWith('agent.skill.read')),
        hasLength(1),
      );
      final diagnostic = events.map((e) => e.message).join();
      for (final excluded in [
        'facts',
        'guide.md',
        'never execute',
        root.path,
      ]) {
        expect(diagnostic, isNot(contains(excluded)));
      }
    },
  );
  for (final path in ['../SKILL.md', 'folder/../../SKILL.md', 'C:/SKILL.md']) {
    test('skill archive rejects unsafe path: $path', () async {
      await expectLater(
        skills.importPackage(await zip([ArchiveFile.string(path, 'bad')])),
        throwsFormatException,
      );
    });
  }
  test('skill archive rejects case aliases and symlinks', () async {
    await expectLater(
      skills.importPackage(
        await zip([
          ArchiveFile.string('SKILL.md', 'hello'),
          ArchiveFile.string('skill.md', 'duplicate'),
        ]),
      ),
      throwsFormatException,
    );
    await expectLater(
      skills.importPackage(
        await zip([
          ArchiveFile.string('SKILL.md', 'hello'),
          ArchiveFile.string('reference', '/outside')
            ..symbolicLink = '/outside'
            ..mode = 0xA1FF,
        ]),
      ),
      throwsFormatException,
    );
  });
  test(
    'nested YAML is not treated as executable or expanded metadata',
    () async {
      await expectLater(
        skills.importPackage(
          await zip([
            ArchiveFile.string('SKILL.md', '---\nname: [one, two]\n---\nbody'),
          ]),
        ),
        throwsFormatException,
      );
    },
  );
}
