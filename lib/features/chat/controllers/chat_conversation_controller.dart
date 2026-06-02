import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:servllama/features/chat/controllers/chat_session_list_controller.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';

class ChatConversationController extends ChangeNotifier {
  ChatConversationController({
    required ChatSessionRepository repository,
    required ChatSessionListController sessionList,
    required this.messageWindowSize,
  }) : _repository = repository,
       _sessionList = sessionList;

  final ChatSessionRepository _repository;
  final ChatSessionListController _sessionList;
  final int messageWindowSize;

  List<ChatMessageRecord> _visibleMessages = <ChatMessageRecord>[];
  bool _isLoadingMessages = false;
  bool _isLoadingOlderMessages = false;
  String? _selectedSessionId;
  int _sessionLoadGeneration = 0;

  String? get selectedSessionId => _selectedSessionId;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingOlderMessages => _isLoadingOlderMessages;

  ChatSessionRecord? get selectedSession =>
      _sessionList.findSession(_selectedSessionId);
  bool get isShowingDraftSession => _selectedSessionId == null;

  List<ChatMessageRecord> get visibleMessages =>
      List<ChatMessageRecord>.from(_visibleMessages, growable: false);

  bool get hasOlderMessages {
    final session = selectedSession;
    if (session == null || _visibleMessages.isEmpty) {
      return false;
    }
    final firstVisibleId = _visibleMessages.first.id;
    final firstVisibleIndex = session.messageIds.indexOf(firstVisibleId);
    return firstVisibleIndex > 0;
  }

  void clearSelection({bool notify = true}) {
    _selectedSessionId = null;
    _visibleMessages = <ChatMessageRecord>[];
    _isLoadingMessages = false;
    _isLoadingOlderMessages = false;
    _sessionLoadGeneration += 1;
    if (notify) {
      notifyListeners();
    }
  }

  void clearIfSelectedSessionMissing({bool notify = true}) {
    if (_selectedSessionId == null ||
        _sessionList.findSession(_selectedSessionId) != null) {
      return;
    }
    clearSelection(notify: notify);
  }

  bool beginSessionSelection(
    String sessionId, {
    bool keepVisibleMessages = true,
  }) {
    final session = _sessionList.findSession(sessionId);
    if (session == null) {
      return false;
    }
    if (_selectedSessionId == sessionId && !_isLoadingMessages) {
      return false;
    }
    _selectedSessionId = sessionId;
    _isLoadingMessages = false;
    _isLoadingOlderMessages = false;
    _sessionLoadGeneration += 1;
    if (!keepVisibleMessages) {
      _visibleMessages = <ChatMessageRecord>[];
    }
    notifyListeners();
    return true;
  }

  Future<void> selectSession(String sessionId) async {
    if (_selectedSessionId == sessionId && !_isLoadingMessages) {
      return;
    }
    final session = _sessionList.findSession(sessionId);
    if (session == null) {
      return;
    }
    final generation = ++_sessionLoadGeneration;
    _selectedSessionId = sessionId;
    _visibleMessages = <ChatMessageRecord>[];
    _isLoadingMessages = true;
    notifyListeners();

    await _loadMessagesForSession(session, generation);
  }

  Future<void> loadSelectedSessionMessages(String sessionId) async {
    final session = _sessionList.findSession(sessionId);
    if (session == null || _selectedSessionId != sessionId) {
      return;
    }
    final generation = ++_sessionLoadGeneration;
    _isLoadingMessages = true;
    notifyListeners();

    await _loadMessagesForSession(session, generation);
  }

  Future<void> _loadMessagesForSession(
    ChatSessionRecord session,
    int generation,
  ) async {
    try {
      final messages = await _repository.loadRecentMessages(
        session,
        limit: messageWindowSize,
      );
      if (generation != _sessionLoadGeneration) {
        return;
      }
      _visibleMessages = messages;
    } catch (_) {
      if (generation != _sessionLoadGeneration) {
        return;
      }
      _visibleMessages = <ChatMessageRecord>[];
    } finally {
      if (generation == _sessionLoadGeneration) {
        _isLoadingMessages = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadOlderMessages() async {
    final session = selectedSession;
    if (session == null ||
        _visibleMessages.isEmpty ||
        _isLoadingMessages ||
        _isLoadingOlderMessages ||
        !hasOlderMessages) {
      return;
    }

    _isLoadingOlderMessages = true;
    notifyListeners();

    try {
      final olderMessages = await _repository.loadMessagesBefore(
        session,
        beforeMessageId: _visibleMessages.first.id,
        limit: messageWindowSize,
      );
      if (olderMessages.isNotEmpty && _selectedSessionId == session.id) {
        _visibleMessages = <ChatMessageRecord>[
          ...olderMessages,
          ..._visibleMessages,
        ];
      }
    } catch (_) {
    } finally {
      _isLoadingOlderMessages = false;
      notifyListeners();
    }
  }

  void startDraftSession(String sessionId, {bool notify = true}) {
    _selectedSessionId = sessionId;
    _visibleMessages = <ChatMessageRecord>[];
    _isLoadingMessages = false;
    _isLoadingOlderMessages = false;
    _sessionLoadGeneration += 1;
    if (notify) {
      notifyListeners();
    }
  }

  void syncVisibleMessagesFromFullMessages(
    String sessionId,
    List<ChatMessageRecord> fullMessages, {
    bool notify = true,
  }) {
    if (_selectedSessionId != sessionId) {
      return;
    }
    if (fullMessages.isEmpty) {
      _visibleMessages = <ChatMessageRecord>[];
      if (notify) {
        notifyListeners();
      }
      return;
    }
    if (_visibleMessages.isNotEmpty) {
      final firstVisibleId = _visibleMessages.first.id;
      final firstVisibleIndex = fullMessages.indexWhere(
        (message) => message.id == firstVisibleId,
      );
      if (firstVisibleIndex >= 0) {
        _visibleMessages = fullMessages
            .skip(firstVisibleIndex)
            .toList(growable: false);
        if (notify) {
          notifyListeners();
        }
        return;
      }
    }
    final targetCount = min(
      fullMessages.length,
      max(messageWindowSize, _visibleMessages.length),
    );
    _visibleMessages = fullMessages
        .skip(fullMessages.length - targetCount)
        .toList(growable: false);
    if (notify) {
      notifyListeners();
    }
  }

  int messageIndex(List<ChatMessageRecord> messages, String messageId) {
    return messages.indexWhere((message) => message.id == messageId);
  }

  int nearestUserMessageIndex(
    List<ChatMessageRecord> messages,
    int startIndex,
  ) {
    for (var index = startIndex; index >= 0; index -= 1) {
      if (messages[index].role == ChatRole.user) {
        return index;
      }
    }
    return -1;
  }
}
