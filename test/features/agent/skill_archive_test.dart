import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
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
  test('pasted markdown uses its heading and requires a description', () async {
    const markdown =
        '---\ndescription: Pasted fixture\n---\n'
        '# Pasted instructions\n\nKeep this text unchanged.';
    final skill = await skills.importMarkdown(markdown);
    expect(skill.name, 'Pasted instructions');
    expect(skill.description, 'Pasted fixture');
    expect(skill.source, SkillSource.paste);
    expect(await skills.read(skill), markdown);
  });
  test('empty pasted markdown is rejected', () async {
    await expectLater(skills.importMarkdown(' \n '), throwsFormatException);
  });
  test('skill metadata requires both name and description', () async {
    await expectLater(
      skills.importMarkdown('---\nname: Missing description\n---\nbody'),
      throwsA(
        isA<SkillFormatException>().having(
          (error) => error.error,
          'error',
          SkillFormatError.missingDescription,
        ),
      ),
    );
    await expectLater(
      skills.importMarkdown('---\ndescription: Missing name\n---\nbody'),
      throwsA(
        isA<SkillFormatException>().having(
          (error) => error.error,
          'error',
          SkillFormatError.missingName,
        ),
      ),
    );
  });
  test('legacy records default to enabled and expose incomplete metadata', () {
    final record = SkillRecord.fromJson({
      'id': 'legacy',
      'name': 'Legacy skill',
      'path': '${root.path}/skills/legacy',
      'hash': 'legacy',
      'description': '',
    });
    expect(record.enabled, isTrue);
    expect(record.source, SkillSource.unknown);
    expect(record.installedAt, isNull);
    expect(record.hasValidMetadata, isFalse);
  });
  test('disabled state and edited metadata persist together', () async {
    final skill = await skills.importMarkdown(
      '---\nname: Before\ndescription: Before edit\n---\n# Before\nbody',
    );
    final disabled = await skills.setEnabled(skill, false);
    expect(disabled.enabled, isFalse);
    expect((await skills.list()).single.enabled, isFalse);

    final updated = await skills.updateMarkdown(
      disabled,
      '---\nname: After\ndescription: After edit\n---\n# After\nnew body',
    );
    expect(updated.name, 'After');
    expect(updated.description, 'After edit');
    expect(updated.hash, isNot(skill.hash));
    expect(updated.enabled, isFalse);
    expect(updated.installedAt, skill.installedAt);
    expect(updated.updatedAt, isNotNull);
    expect(await skills.read(updated), contains('new body'));
    expect((await skills.list()).single.toJson(), updated.toJson());
  });
  test('failed markdown save restores the previous file and record', () async {
    const original =
        '---\nname: Original\ndescription: Original text\n---\nbody';
    final skill = await skills.importMarkdown(original);
    await db.execute(
      "CREATE TRIGGER reject_skill_update BEFORE UPDATE ON skills "
      "BEGIN SELECT RAISE(ABORT,'fixture'); END",
    );

    await expectLater(
      skills.updateMarkdown(
        skill,
        '---\nname: Changed\ndescription: Changed text\n---\nnew body',
      ),
      throwsA(anything),
    );
    expect(await skills.read(skill), original);
    expect((await skills.list()).single.toJson(), skill.toJson());
  });
  test('exported ZIP contains the complete static skill package', () async {
    final skill = await skills.importPackage(
      await zip([
        ArchiveFile.string(
          'exported/SKILL.md',
          '---\nname: Exported\ndescription: Export fixture\n---\nbody',
        ),
        ArchiveFile.string('exported/references/guide.md', 'facts'),
      ]),
    );
    final output = await skills.exportZip(
      skill,
      Directory('${root.path}/exports'),
    );
    final archive = ZipDecoder().decodeBytes(await output.readAsBytes());
    expect(
      archive.files.map((file) => file.name),
      containsAll(['SKILL.md', 'references/guide.md']),
    );
    expect(
      utf8.decode(archive.findFile('references/guide.md')!.content),
      'facts',
    );
  });
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
