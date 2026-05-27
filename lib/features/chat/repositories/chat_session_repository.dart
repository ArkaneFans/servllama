import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_message_version_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';

class ChatSessionRepository {
  ChatSessionRepository({Directory? appSupportDirectory, HiveInterface? hive})
    : _appSupportDirectory = appSupportDirectory,
      _hive = hive ?? Hive;

  static const String boxName = 'chat_sessions';
  static const String versionBoxName = 'chat_message_versions';

  final Directory? _appSupportDirectory;
  final HiveInterface _hive;

  Future<Box<ChatSessionRecord>>? _boxFuture;
  Future<Box<ChatMessageVersionRecord>>? _versionBoxFuture;
  String? _initializedHivePath;

  Future<List<ChatSessionRecord>> loadSessions() async {
    final box = await _box();
    final sessions = box.values.toList();
    sessions.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return sessions;
  }

  Future<void> saveSession(ChatSessionRecord session) async {
    final box = await _box();
    await box.put(session.id, session);
  }

  Future<void> deleteSession(String sessionId) async {
    final box = await _box();
    final session = box.get(sessionId);
    if (session != null) {
      await deleteMessageResources(session.messages);
    }
    await box.delete(sessionId);
  }

  Future<void> saveMessageVersion(ChatMessageVersionRecord version) async {
    final box = await _versionBox();
    await box.put(version.id, version);
  }

  Future<ChatMessageVersionRecord?> loadMessageVersion(String versionId) async {
    final box = await _versionBox();
    return box.get(versionId);
  }

  Future<List<ChatMessageVersionRecord>> loadMessageVersions(
    Iterable<String> versionIds,
  ) async {
    final box = await _versionBox();
    return versionIds
        .map(box.get)
        .whereType<ChatMessageVersionRecord>()
        .toList(growable: false);
  }

  Future<void> deleteMessageVersions(Iterable<String> versionIds) async {
    final ids = versionIds.toSet();
    if (ids.isEmpty) {
      return;
    }
    final box = await _versionBox();
    final versions = ids.map(box.get).whereType<ChatMessageVersionRecord>();
    await deleteAttachmentFiles(
      versions.expand((version) => version.imageFilePaths),
    );
    await box.deleteAll(ids);
  }

  Future<void> deleteMessageResources(
    Iterable<ChatMessageRecord> messages,
  ) async {
    final messageList = messages.toList(growable: false);
    await deleteAttachmentFiles(
      messageList.expand((message) => message.imageFilePaths),
    );
    await deleteMessageVersions(
      messageList.expand((message) => message.versionIds),
    );
  }

  Future<void> deleteAttachmentFiles(Iterable<String> filePaths) async {
    for (final filePath in filePaths) {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }

  Future<Box<ChatSessionRecord>> _box() async {
    return _boxFuture ??= _openBox();
  }

  Future<Box<ChatMessageVersionRecord>> _versionBox() async {
    return _versionBoxFuture ??= _openVersionBox();
  }

  Future<Box<ChatSessionRecord>> _openBox() async {
    await _ensureHiveInitialized();
    _registerAdapters();
    if (_hive.isBoxOpen(boxName)) {
      return _hive.box<ChatSessionRecord>(boxName);
    }
    return _hive.openBox<ChatSessionRecord>(boxName);
  }

  Future<Box<ChatMessageVersionRecord>> _openVersionBox() async {
    await _ensureHiveInitialized();
    _registerAdapters();
    if (_hive.isBoxOpen(versionBoxName)) {
      return _hive.box<ChatMessageVersionRecord>(versionBoxName);
    }
    return _hive.openBox<ChatMessageVersionRecord>(versionBoxName);
  }

  void _registerAdapters() {
    if (!_hive.isAdapterRegistered(1)) {
      _hive.registerAdapter(ChatMessageRecordAdapter());
    }
    if (!_hive.isAdapterRegistered(2)) {
      _hive.registerAdapter(ChatSessionRecordAdapter());
    }
    if (!_hive.isAdapterRegistered(3)) {
      _hive.registerAdapter(ChatRoleAdapter());
    }
    if (!_hive.isAdapterRegistered(4)) {
      _hive.registerAdapter(ChatMessageVersionRecordAdapter());
    }
  }

  Future<void> _ensureHiveInitialized() async {
    final directory =
        _appSupportDirectory ?? await getApplicationSupportDirectory();
    if (_initializedHivePath == directory.path) {
      return;
    }
    _hive.init(directory.path);
    _initializedHivePath = directory.path;
  }
}
