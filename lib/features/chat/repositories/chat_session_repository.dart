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
  static const String messageBoxName = 'chat_messages';
  static const String versionBoxName = 'chat_message_versions';

  final Directory? _appSupportDirectory;
  final HiveInterface _hive;

  Future<Box<ChatSessionRecord>>? _boxFuture;
  Future<Box<ChatMessageRecord>>? _messageBoxFuture;
  Future<Box<ChatMessageVersionRecord>>? _versionBoxFuture;
  String? _initializedHivePath;

  Future<List<ChatSessionRecord>> loadSessions() async {
    final box = await _box();
    final sessions = <ChatSessionRecord>[];
    final storedSessions = box.values.toList(growable: false);
    for (final session in storedSessions) {
      sessions.add(await _migrateLegacySessionMessages(session));
    }
    sessions.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    return sessions;
  }

  Future<void> saveSession(ChatSessionRecord session) async {
    final box = await _box();
    final cleanSession = await _saveLegacyMessagesIfNeeded(session);
    await box.put(cleanSession.id, _withoutLegacyMessages(cleanSession));
  }

  Future<ChatSessionRecord> saveSessionWithMessages(
    ChatSessionRecord session,
    List<ChatMessageRecord> messages,
  ) async {
    final box = await _box();
    final savedMessages = await _saveMessagesForSession(session.id, messages);
    final cleanSession = _withoutLegacyMessages(
      session.copyWith(
        messageIds: savedMessages
            .map((message) => message.id)
            .toList(growable: false),
        legacyMessages: const <ChatMessageRecord>[],
      ),
    );
    await box.put(cleanSession.id, cleanSession);
    return cleanSession;
  }

  Future<List<ChatMessageRecord>> loadRecentMessages(
    ChatSessionRecord session, {
    int limit = 30,
  }) async {
    final ids = session.messageIds;
    final start = ids.length > limit ? ids.length - limit : 0;
    return _loadMessagesByIds(ids.skip(start));
  }

  Future<List<ChatMessageRecord>> loadMessagesBefore(
    ChatSessionRecord session, {
    required String beforeMessageId,
    int limit = 30,
  }) async {
    final beforeIndex = session.messageIds.indexOf(beforeMessageId);
    if (beforeIndex <= 0) {
      return const <ChatMessageRecord>[];
    }
    final start = beforeIndex > limit ? beforeIndex - limit : 0;
    return _loadMessagesByIds(session.messageIds.sublist(start, beforeIndex));
  }

  Future<List<ChatMessageRecord>> loadAllMessages(
    ChatSessionRecord session,
  ) async {
    return _loadMessagesByIds(session.messageIds);
  }

  Future<void> deleteSession(String sessionId) async {
    final box = await _box();
    final session = box.get(sessionId);
    if (session != null) {
      final messages = session.legacyMessages.isNotEmpty
          ? session.legacyMessages
          : await loadAllMessages(session);
      await deleteMessages(messages);
    }
    await box.delete(sessionId);
  }

  Future<void> deleteMessages(Iterable<ChatMessageRecord> messages) async {
    final messageList = messages.toList(growable: false);
    if (messageList.isEmpty) {
      return;
    }
    await deleteMessageResources(messageList);
    final box = await _messageBox();
    await box.deleteAll(messageList.map((message) => message.id));
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

  Future<Box<ChatMessageRecord>> _messageBox() async {
    return _messageBoxFuture ??= _openMessageBox();
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

  Future<Box<ChatMessageRecord>> _openMessageBox() async {
    await _ensureHiveInitialized();
    _registerAdapters();
    if (_hive.isBoxOpen(messageBoxName)) {
      return _hive.box<ChatMessageRecord>(messageBoxName);
    }
    return _hive.openBox<ChatMessageRecord>(messageBoxName);
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

  Future<ChatSessionRecord> _migrateLegacySessionMessages(
    ChatSessionRecord session,
  ) async {
    if (session.legacyMessages.isEmpty) {
      return _withoutLegacyMessages(session);
    }
    final cleanSession = await _saveLegacyMessagesIfNeeded(session);
    final box = await _box();
    await box.put(cleanSession.id, cleanSession);
    return cleanSession;
  }

  Future<ChatSessionRecord> _saveLegacyMessagesIfNeeded(
    ChatSessionRecord session,
  ) async {
    if (session.legacyMessages.isEmpty) {
      return _withoutLegacyMessages(session);
    }
    final savedMessages = await _saveMessagesForSession(
      session.id,
      session.legacyMessages,
    );
    return _withoutLegacyMessages(
      session.copyWith(
        messageIds: savedMessages
            .map((message) => message.id)
            .toList(growable: false),
        legacyMessages: const <ChatMessageRecord>[],
      ),
    );
  }

  Future<List<ChatMessageRecord>> _saveMessagesForSession(
    String sessionId,
    Iterable<ChatMessageRecord> messages,
  ) async {
    final box = await _messageBox();
    final savedMessages = messages
        .map((message) => _messageForSession(sessionId, message))
        .toList(growable: false);
    for (final message in savedMessages) {
      await box.put(message.id, message);
    }
    return savedMessages;
  }

  Future<List<ChatMessageRecord>> _loadMessagesByIds(
    Iterable<String> messageIds,
  ) async {
    final box = await _messageBox();
    return messageIds
        .map(box.get)
        .whereType<ChatMessageRecord>()
        .toList(growable: false);
  }

  ChatMessageRecord _messageForSession(
    String sessionId,
    ChatMessageRecord message,
  ) {
    if (message.sessionId == sessionId) {
      return message;
    }
    return message.copyWith(sessionId: sessionId);
  }

  ChatSessionRecord _withoutLegacyMessages(ChatSessionRecord session) {
    if (session.legacyMessages.isEmpty) {
      return session;
    }
    return session.copyWith(legacyMessages: const <ChatMessageRecord>[]);
  }
}
