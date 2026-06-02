import 'package:flutter/foundation.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';

class ChatSessionListController extends ChangeNotifier {
  ChatSessionListController({required ChatSessionRepository repository})
    : _repository = repository;

  final ChatSessionRepository _repository;

  List<ChatSessionRecord> _sessions = <ChatSessionRecord>[];
  bool _isInitialized = false;
  bool _isLoading = false;
  String _query = '';

  List<ChatSessionRecord> get sessions =>
      List<ChatSessionRecord>.unmodifiable(_sessions);
  bool get isLoading => _isLoading;
  String get query => _query;

  List<ChatSessionRecord> get filteredSessions {
    final normalizedQuery = _query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return sessions;
    }
    return _sessions
        .where(
          (session) => session.title.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }

  Future<void> load() async {
    if (_isInitialized || _isLoading) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _sessions = List<ChatSessionRecord>.from(
        await _repository.loadSessions(),
      );
      _isInitialized = true;
    } catch (_) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateQuery(String value) {
    if (_query == value) {
      return;
    }
    _query = value;
    notifyListeners();
  }

  Future<void> renameSession(String sessionId, String title) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      return;
    }

    final session = findSession(sessionId);
    if (session == null) {
      return;
    }

    await saveSession(
      session.copyWith(title: normalizedTitle, updatedAt: DateTime.now()),
    );
  }

  Future<bool> deleteSession(String sessionId) async {
    final session = findSession(sessionId);
    if (session == null) {
      return false;
    }

    final nextSessions = List<ChatSessionRecord>.from(_sessions);
    nextSessions.removeWhere((item) => item.id == sessionId);
    _sessions = nextSessions;
    await _repository.deleteSession(sessionId);
    notifyListeners();
    return true;
  }

  Future<void> saveSession(
    ChatSessionRecord session, {
    bool notify = true,
  }) async {
    await _repository.saveSession(session);
    upsertSession(session, notify: notify);
  }

  void upsertSession(ChatSessionRecord session, {bool notify = true}) {
    final nextSessions = List<ChatSessionRecord>.from(_sessions);
    final index = nextSessions.indexWhere((item) => item.id == session.id);
    if (index >= 0) {
      nextSessions[index] = session;
    } else {
      nextSessions.add(session);
    }
    nextSessions.sort(
      (left, right) => right.updatedAt.compareTo(left.updatedAt),
    );
    _sessions = nextSessions;
    if (notify) {
      notifyListeners();
    }
  }

  ChatSessionRecord? findSession(String? sessionId) {
    if (sessionId == null) {
      return null;
    }
    for (final session in _sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }
}
