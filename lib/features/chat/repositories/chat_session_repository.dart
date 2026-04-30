import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';

class ChatSessionRepository {
  ChatSessionRepository({
    Directory? appSupportDirectory,
    HiveInterface? hive,
  }) : _appSupportDirectory = appSupportDirectory,
       _hive = hive ?? Hive;

  static const String boxName = 'chat_sessions';

  final Directory? _appSupportDirectory;
  final HiveInterface _hive;

  Future<Box<ChatSessionRecord>>? _boxFuture;
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
    await box.delete(sessionId);
  }

  Future<Box<ChatSessionRecord>> _box() async {
    return _boxFuture ??= _openBox();
  }

  Future<Box<ChatSessionRecord>> _openBox() async {
    await _ensureHiveInitialized();
    if (!_hive.isAdapterRegistered(1)) {
      _hive.registerAdapter(ChatMessageRecordAdapter());
    }
    if (!_hive.isAdapterRegistered(2)) {
      _hive.registerAdapter(ChatSessionRecordAdapter());
    }
    if (!_hive.isAdapterRegistered(3)) {
      _hive.registerAdapter(ChatRoleAdapter());
    }
    if (_hive.isBoxOpen(boxName)) {
      return _hive.box<ChatSessionRecord>(boxName);
    }
    return _hive.openBox<ChatSessionRecord>(boxName);
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
