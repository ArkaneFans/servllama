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
  static const maxPackageBytes = 10 * 1024 * 1024;
  static const maxEntries = 128;
  static const maxTextBytes = 64 * 1024;
  static const _textExtensions = {
    '.md',
    '.txt',
    '.json',
    '.yaml',
    '.yml',
    '.csv',
    '.xml',
    '.html',
    '.htm',
    '.js',
    '.ts',
    '.py',
    '.sh',
    '.bat',
    '.ps1',
    '.toml',
    '.ini',
    '.log',
  };

  final AppLogger _logger;
  final AgentRepository repository;
  final Directory root;

  Future<List<SkillRecord>> list() => repository.skills();

  Future<SkillRecord?> pickAndImport() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'md'],
    );
    final path = picked?.files.single.path;
    return path == null ? null : importPackage(File(path));
  }

  Future<SkillRecord> importMarkdown(String markdown) =>
      _trackImport(() => _importMarkdown(markdown, SkillSource.paste));

  Future<SkillRecord> importPackage(File source) =>
      _trackImport(() => _importPackage(source));

  Future<SkillRecord> _trackImport(
    Future<SkillRecord> Function() operation,
  ) async {
    final watch = Stopwatch()..start();
    _logger.event('agent.skill.import_started', channel: LogChannel.agent);
    try {
      final skill = await operation();
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
    if (await source.length() > maxPackageBytes) {
      throw const FormatException('Skill package exceeds 10 MiB');
    }
    final entries = <String, List<int>>{};
    if (p.extension(source.path).toLowerCase() == '.md') {
      entries['SKILL.md'] = await source.readAsBytes();
    } else {
      final archive = readBoundedZip(
        InputMemoryStream(await source.readAsBytes()),
        maxEntries: maxEntries,
        maxExpandedBytes: maxPackageBytes,
      );
      var total = 0;
      final names = <String>{};
      if (archive.length > maxEntries) {
        throw const FormatException('Too many skill files');
      }
      for (final f in archive) {
        if (f.isSymbolicLink) {
          throw const FormatException('Skill links are not allowed');
        }
        if (!f.isFile) continue;
        total += f.size;
        if (total > maxPackageBytes) {
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
    return _importEntries(entries, source: SkillSource.file);
  }

  Future<SkillRecord> _importMarkdown(
    String markdown,
    SkillSource source,
  ) async {
    if (markdown.trim().isEmpty) {
      throw const FormatException('Skill text is empty');
    }
    return _importEntries({'SKILL.md': utf8.encode(markdown)}, source: source);
  }

  Future<SkillRecord> _importEntries(
    Map<String, List<int>> entries, {
    required SkillSource source,
  }) async {
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
    if (utf8.encode(body).length > maxTextBytes) {
      throw const FormatException('SKILL.md exceeds 64 KiB');
    }
    final parsed = _parseMetadata(body);
    final id = newId();
    final folder = Directory(p.join(root.path, 'skills', id));
    await folder.create(recursive: true);
    try {
      for (final entry in normalized.entries) {
        final f = File(p.join(folder.path, entry.key));
        await f.parent.create(recursive: true);
        await f.writeAsBytes(entry.value, flush: true);
      }
      final now = DateTime.now().toUtc();
      final record = SkillRecord(
        id: id,
        name: parsed.name,
        path: folder.path,
        hash: await fingerprint(folder),
        description: parsed.description,
        hasScripts: normalized.keys.any(
          (n) =>
              n.startsWith('scripts/') ||
              ['.py', '.sh', '.js', '.bat', '.exe'].contains(p.extension(n)),
        ),
        source: source,
        installedAt: now,
        updatedAt: now,
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

  ({String name, String description}) _parseMetadata(String markdown) {
    final front = RegExp(r'^---\r?\n([\s\S]*?)\r?\n---').firstMatch(markdown);
    Object? yaml;
    if (front != null) {
      try {
        yaml = loadYaml(front[1]!);
      } catch (_) {
        throw const SkillFormatException(
          SkillFormatError.invalidMetadata,
          'Invalid skill metadata',
        );
      }
    }
    final rawName = yaml is YamlMap ? yaml['name'] : null;
    final rawDescription = yaml is YamlMap ? yaml['description'] : null;
    if ((rawName != null && rawName is! String) ||
        (rawDescription != null && rawDescription is! String)) {
      throw const SkillFormatException(
        SkillFormatError.invalidMetadata,
        'Skill name and description must be text',
      );
    }
    final body = front == null ? markdown : markdown.substring(front.end);
    final name = (rawName as String?)?.trim().isNotEmpty == true
        ? (rawName as String).trim()
        : _firstHeading(body);
    final description = (rawDescription as String?)?.trim() ?? '';
    if (name.isEmpty) {
      throw const SkillFormatException(
        SkillFormatError.missingName,
        'Skill name is required',
      );
    }
    if (description.isEmpty) {
      throw const SkillFormatException(
        SkillFormatError.missingDescription,
        'Skill description is required',
      );
    }
    if (name.length > 120 || description.length > 2048) {
      throw const SkillFormatException(
        SkillFormatError.invalidMetadata,
        'Skill name and description must be short text',
      );
    }
    return (name: name, description: description);
  }

  String _firstHeading(String markdown) {
    for (final line in markdown.split('\n')) {
      final match = RegExp(r'^#{1,6}\s+(.+?)\s*$').firstMatch(line.trim());
      if (match != null) return match.group(1)!.trim();
    }
    return '';
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

  Future<SkillDetails> details(SkillRecord skill) async {
    final folder = _folder(skill);
    await _ensureUnchanged(skill);
    final files = await _listFiles(folder);
    return SkillDetails(record: skill, files: files);
  }

  Future<SkillRecord> setEnabled(SkillRecord skill, bool enabled) async {
    final next = skill.copyWith(enabled: enabled);
    await repository.saveSkill(next);
    return next;
  }

  Future<SkillRecord> updateMarkdown(SkillRecord skill, String markdown) async {
    if (markdown.trim().isEmpty) {
      throw const FormatException('Skill text is empty');
    }
    if (utf8.encode(markdown).length > maxTextBytes) {
      throw const FormatException('SKILL.md exceeds 64 KiB');
    }
    final parsed = _parseMetadata(markdown);
    final folder = _folder(skill);
    await _ensureUnchanged(skill);
    final skillMd = File(p.join(folder.path, 'SKILL.md'));
    if (!await skillMd.exists()) {
      throw const FormatException('SKILL.md is missing');
    }

    final editRoot = Directory(p.join(root.path, 'skills'));
    await editRoot.create(recursive: true);
    final suffix = newId();
    final temp = File(p.join(editRoot.path, '.skill-tmp-$suffix'));
    final backup = File(p.join(editRoot.path, '.skill-backup-$suffix'));
    var committed = false;
    try {
      await temp.writeAsBytes(utf8.encode(markdown), flush: true);
      await skillMd.rename(backup.path);
      await temp.rename(skillMd.path);
      final hash = await fingerprint(folder);
      final files = await _listFiles(folder);
      final next = skill.copyWith(
        name: parsed.name,
        description: parsed.description,
        hash: hash,
        hasScripts: files.any((file) => _isScriptPath(file.relativePath)),
        updatedAt: DateTime.now().toUtc(),
      );
      await repository.saveSkill(next);
      committed = true;
      return next;
    } catch (_) {
      if (await backup.exists()) {
        if (await skillMd.exists()) await skillMd.delete();
        await backup.rename(skillMd.path);
      }
      rethrow;
    } finally {
      if (await temp.exists()) await temp.delete();
      if (committed && await backup.exists()) {
        try {
          await backup.delete();
        } catch (_) {}
      }
    }
  }

  Future<File> exportZip(SkillRecord skill, Directory outDir) async {
    final folder = _folder(skill);
    await _ensureUnchanged(skill);
    final archive = Archive();
    for (final entry in (await _readEntries(folder)).entries) {
      archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
    }
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    final output = File(p.join(outDir.path, '${skill.id}.zip'));
    await output.writeAsBytes(ZipEncoder().encode(archive), flush: true);
    return output;
  }

  Future<String> read(
    SkillRecord skill, {
    String relativePath = 'SKILL.md',
  }) async {
    final folder = _folder(skill);
    await _ensureUnchanged(skill);
    final file = File(p.join(folder.path, _relative(relativePath)));
    if (await file.length() > maxTextBytes) {
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

  Directory _folder(SkillRecord skill) {
    final expected = p.normalize(p.join(root.path, 'skills', skill.id));
    if (!p.equals(p.normalize(skill.path), expected)) {
      throw const FormatException('Unsafe skill path');
    }
    return Directory(expected);
  }

  Future<void> _ensureUnchanged(SkillRecord skill) async {
    final folder = _folder(skill);
    if (!await folder.exists() || await fingerprint(folder) != skill.hash) {
      throw const FormatException('Skill changed; re-import before use');
    }
  }

  Future<List<SkillFileEntry>> _listFiles(Directory folder) async {
    final entities = await folder
        .list(recursive: true, followLinks: false)
        .toList();
    entities.sort((a, b) => a.path.compareTo(b.path));
    final files = <SkillFileEntry>[];
    var total = 0;
    for (final entity in entities) {
      if (entity is Link) throw const FormatException('Skill symlink');
      if (entity is! File) continue;
      if (files.length >= maxEntries) {
        throw const FormatException('Too many skill files');
      }
      final size = await entity.length();
      total += size;
      if (total > maxPackageBytes) {
        throw const FormatException('Skill size changed');
      }
      final relative = p
          .relative(entity.path, from: folder.path)
          .replaceAll(r'\', '/');
      files.add(
        SkillFileEntry(
          relativePath: relative,
          size: size,
          isText: _isTextPath(relative),
        ),
      );
    }
    return files;
  }

  Future<Map<String, List<int>>> _readEntries(Directory folder) async {
    final result = <String, List<int>>{};
    var total = 0;
    for (final entity
        in await folder.list(recursive: true, followLinks: false).toList()) {
      if (entity is Link) throw const FormatException('Skill symlink');
      if (entity is! File) continue;
      if (result.length >= maxEntries) {
        throw const FormatException('Too many skill files');
      }
      final bytes = await entity.readAsBytes();
      total += bytes.length;
      if (total > maxPackageBytes) {
        throw const FormatException('Skill size changed');
      }
      final relative = p
          .relative(entity.path, from: folder.path)
          .replaceAll(r'\', '/');
      result[relative] = bytes;
    }
    return result;
  }

  bool _isTextPath(String path) =>
      _textExtensions.contains(p.extension(path).toLowerCase());

  bool _isScriptPath(String path) =>
      const {
        '.sh',
        '.bat',
        '.ps1',
        '.py',
        '.js',
        '.exe',
      }.contains(p.extension(path).toLowerCase()) ||
      path.startsWith('scripts/');

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
