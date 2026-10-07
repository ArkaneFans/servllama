import 'dart:convert';
import 'dart:io';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/core/storage/bounded_archive_output.dart';
import 'package:servllama/core/storage/bounded_zip_reader.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';

class SkillService {
  SkillService(this.repository, this.root, {AppLogger? logger})
    : _logger = logger ?? AppLogger.instance;
  final AppLogger _logger;
  final AgentRepository repository;
  final Directory root;
  Future<SkillRecord?> pickAndImport() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'md'],
    );
    final path = picked?.files.single.path;
    return path == null ? null : importPackage(File(path));
  }

  Future<SkillRecord> importPackage(File source) async {
    final watch = Stopwatch()..start();
    _logger.event('agent.skill.import_started', channel: LogChannel.agent);
    try {
      final skill = await _importPackage(source);
      _logger.event(
        'agent.skill.import_completed',
        channel: LogChannel.agent,
        fields: {
          'skill': skill.id,
          'scripts_present': skill.hasScripts,
          'elapsed_ms': watch.elapsedMilliseconds,
        },
      );
      return skill;
    } catch (error) {
      _logger.event(
        'agent.skill.import_failed',
        channel: LogChannel.agent,
        level: LogLevel.error,
        fields: {
          'elapsed_ms': watch.elapsedMilliseconds,
          ...AppLogger.errorFields(error),
        },
      );
      rethrow;
    }
  }

  Future<SkillRecord> _importPackage(File source) async {
    if (await source.length() > 10 * 1024 * 1024) {
      throw const FormatException('Skill package exceeds 10 MiB');
    }
    final entries = <String, List<int>>{};
    if (p.extension(source.path).toLowerCase() == '.md') {
      entries['SKILL.md'] = await source.readAsBytes();
    } else {
      final archive = readBoundedZip(
        InputMemoryStream(await source.readAsBytes()),
        maxEntries: 128,
        maxExpandedBytes: 10 * 1024 * 1024,
      );
      var total = 0;
      final names = <String>{};
      if (archive.length > 128) {
        throw const FormatException('Too many skill files');
      }
      for (final f in archive) {
        if (f.isSymbolicLink) {
          throw const FormatException('Skill links are not allowed');
        }
        if (!f.isFile) continue;
        total += f.size;
        if (total > 10 * 1024 * 1024) {
          throw const FormatException('Expanded skill exceeds 10 MiB');
        }
        final name = _relative(f.name);
        if (!names.add(name.toLowerCase())) {
          throw const FormatException('Duplicate skill path');
        }
        final buffer = OutputMemoryStream();
        f.writeContent(BoundedArchiveOutput(buffer, f.size));
        if (buffer.length != f.size) {
          throw const FormatException('Truncated skill file');
        }
        entries[name] = buffer.getBytes();
      }
    }
    final roots = entries.keys
        .where((v) => p.basename(v) == 'SKILL.md')
        .toList();
    if (roots.length != 1) {
      throw const FormatException('Exactly one SKILL.md is required');
    }
    final base = p.dirname(roots.single);
    final normalized = <String, List<int>>{};
    for (final entry in entries.entries) {
      if (base != '.' && !p.isWithin(base, entry.key)) {
        throw const FormatException('Files outside skill root');
      }
      normalized[(base == '.' ? entry.key : p.relative(entry.key, from: base))
              .replaceAll(r'\', '/')] =
          entry.value;
    }
    final body = utf8.decode(normalized['SKILL.md']!);
    if (body.length > 65536) {
      throw const FormatException('SKILL.md exceeds 64 KiB');
    }
    final front = RegExp(r'^---\r?\n([\s\S]*?)\r?\n---').firstMatch(body);
    final yaml = front == null ? null : loadYaml(front[1]!);
    final Object? name = yaml is YamlMap ? yaml['name'] : null;
    final Object? description = yaml is YamlMap ? yaml['description'] : null;
    if ((name != null && (name is! String || name.length > 120)) ||
        (description != null &&
            (description is! String || description.length > 2048))) {
      throw const FormatException(
        'Skill name and description must be short text',
      );
    }
    final id = newId();
    final folder = Directory(p.join(root.path, 'skills', id));
    await folder.create(recursive: true);
    try {
      for (final entry in normalized.entries) {
        final f = File(p.join(folder.path, entry.key));
        await f.parent.create(recursive: true);
        await f.writeAsBytes(entry.value, flush: true);
      }
      final record = SkillRecord(
        id: id,
        name: name as String? ?? p.basenameWithoutExtension(source.path),
        path: folder.path,
        hash: await fingerprint(folder),
        description: description as String? ?? '',
        hasScripts: normalized.keys.any(
          (n) =>
              n.startsWith('scripts/') ||
              ['.py', '.sh', '.js', '.bat', '.exe'].contains(p.extension(n)),
        ),
      );
      await repository.saveSkill(record);
      return record;
    } catch (_) {
      await folder.delete(recursive: true);
      rethrow;
    }
  }

  String _relative(String path) {
    if (path.length > 240 ||
        path.replaceAll(r'\', '/').split('/').contains('..') ||
        path.contains(RegExp(r'[\x00-\x1f]'))) {
      throw const FormatException('Unsafe skill path');
    }
    final normalized = p.posix.normalize(path.replaceAll(r'\', '/'));
    if (p.posix.isAbsolute(normalized) ||
        normalized == '..' ||
        normalized.startsWith('../') ||
        normalized.contains(':') ||
        normalized.contains('\u0000')) {
      throw const FormatException('Unsafe skill path');
    }
    return normalized;
  }

  Future<String> fingerprint(Directory dir) async {
    final files = await dir.list(recursive: true, followLinks: false).toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    final parts = <int>[];
    for (final f in files) {
      if (f is Link) throw const FormatException('Skill symlink');
      if (f is! File) continue;
      if (await f.length() + parts.length > 11 * 1024 * 1024) {
        throw const FormatException('Skill size changed');
      }
      parts.addAll(
        utf8.encode(p.relative(f.path, from: dir.path).replaceAll(r'\', '/')),
      );
      parts.add(0);
      parts.addAll(await f.readAsBytes());
      parts.add(0);
      if (parts.length > 11 * 1024 * 1024) {
        throw const FormatException('Skill size changed');
      }
    }
    return sha256.convert(parts).toString();
  }

  Future<String> read(
    SkillRecord skill, {
    String relativePath = 'SKILL.md',
  }) async {
    final folder = Directory(skill.path);
    if (await fingerprint(folder) != skill.hash) {
      throw const FormatException('Skill changed; re-import before use');
    }
    final file = File(p.join(folder.path, _relative(relativePath)));
    if (await file.length() > 65536) {
      throw const FormatException('Skill text too large');
    }
    final text = await file.readAsString();
    _logger.event(
      'agent.skill.read',
      channel: LogChannel.agent,
      fields: {'skill': skill.id, 'chars': text.length},
    );
    return text;
  }

  Future<void> delete(SkillRecord skill) async {
    await repository.db.transaction(() async {
      await repository.removeAssistantBindings(skillId: skill.id);
      await repository.db.execute('DELETE FROM skills WHERE id=?', [skill.id]);
    });
    final expected = Directory(p.join(root.path, 'skills', skill.id));
    if (p.equals(expected.path, skill.path) && await expected.exists()) {
      await expected.delete(recursive: true);
    }
    _logger.event(
      'agent.skill.deleted',
      channel: LogChannel.agent,
      fields: {'skill': skill.id},
    );
  }
}
