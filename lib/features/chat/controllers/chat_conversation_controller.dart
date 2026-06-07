import 'dart:collection';
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
    this.initialMessageMin = ChatSessionRepository.defaultInitialMessageMin,
    this.initialMessageMax = ChatSessionRepository.defaultInitialMessageMax,
    this.initialTextBudget = ChatSessionRepository.defaultInitialTextBudget,
    this.initialMessageCacheCapacity = 8,
  }) : _repository = repository,
       _sessionList = sessionList;

  final ChatSessionRepository _repository;
  final ChatSessionListController _sessionList;
  final int messageWindowSize;
  final int initialMessageMin;
  final int initialMessageMax;
  final int initialTextBudget;
  final int initialMessageCacheCapacity;

  List<ChatMessageRecord> _visibleMessages =
      List<ChatMessageRecord>.unmodifiable(const <ChatMessageRecord>[]);
  bool _isLoadingMessages = false;
  bool _isLoadingOlderMessages = false;
  String? _selectedSessionId;
  int _sessionLoadGeneration = 0;
  int _visibleMessagesRevision = 0;
  final LinkedHashMap<String, _InitialMessageCacheEntry> _initialMessageCache =
      LinkedHashMap<String, _InitialMessageCacheEntry>();
  final Map<String, _InitialMessageLoad> _preloadLoads =
      <String, _InitialMessageLoad>{};
  Future<void> _preloadQueue = Future<void>.value();

  String? get selectedSessionId => _selectedSessionId;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isLoadingOlderMessages => _isLoadingOlderMessages;
  int get visibleMessagesRevision => _visibleMessagesRevision;

  ChatSessionRecord? get selectedSession =>
      _sessionList.findSession(_selectedSessionId);
  bool get isShowingDraftSession => _selectedSessionId == null;

  List<ChatMessageRecord> get visibleMessages => _visibleMessages;

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
    _setVisibleMessages(const <ChatMessageRecord>[]);
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
      _setVisibleMessages(const <ChatMessageRecord>[]);
    }
    notifyListeners();
    return true;
  }

  Future<bool> switchSession(String sessionId, {bool staged = false}) async {
    final session = _sessionList.findSession(sessionId);
    if (session == null) {
      return false;
    }
    if (_selectedSessionId == sessionId && !_isLoadingMessages) {
      return false;
    }

    final generation = ++_sessionLoadGeneration;
    final cachedMessages = _cachedInitialMessages(session);
    _selectedSessionId = sessionId;
    _isLoadingOlderMessages = false;
    if (staged) {
      _isLoadingMessages = true;
      notifyListeners();
      if (cachedMessages != null) {
        _commitLoadedMessages(
          sessionId: session.id,
          generation: generation,
          messages: cachedMessages,
        );
        return true;
      }
      await _loadMessagesForSession(session, generation);
      return true;
    }

    _setVisibleMessages(cachedMessages ?? const <ChatMessageRecord>[]);
    _isLoadingMessages = cachedMessages == null;
    notifyListeners();

    if (cachedMessages != null) {
      return true;
    }

    await _loadMessagesForSession(session, generation);
    return true;
  }

  Future<void> selectSession(String sessionId) async {
    await switchSession(sessionId);
  }

  Future<void> loadSelectedSessionMessages(String sessionId) async {
    final session = _sessionList.findSession(sessionId);
    if (session == null || _selectedSessionId != sessionId) {
      return;
    }
    final cachedMessages = _cachedInitialMessages(session);
    if (cachedMessages != null) {
      _setVisibleMessages(cachedMessages);
      _isLoadingMessages = false;
      notifyListeners();
      return;
    }
    final generation = ++_sessionLoadGeneration;
    _isLoadingMessages = true;
    notifyListeners();

    await _loadMessagesForSession(session, generation);
  }

  void preloadInitialMessages(Iterable<ChatSessionRecord> sessions) {
    for (final session in sessions) {
      if (_cachedInitialMessages(session) != null ||
          _activeInitialMessageLoad(session) != null) {
        continue;
      }
      _preloadQueue = _preloadQueue.then((_) async {
        if (_cachedInitialMessages(session) != null ||
            _activeInitialMessageLoad(session) != null) {
          return;
        }
        try {
          await _initialMessagesForSession(session);
        } catch (_) {}
      });
    }
  }

  Future<void> _loadMessagesForSession(
    ChatSessionRecord session,
    int generation,
  ) async {
    try {
      final messages = await _initialMessagesForSession(session);
      if (generation != _sessionLoadGeneration) {
        return;
      }
      _setVisibleMessages(messages);
    } catch (_) {
      if (generation != _sessionLoadGeneration) {
        return;
      }
      _setVisibleMessages(const <ChatMessageRecord>[]);
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
        _setVisibleMessages(<ChatMessageRecord>[
          ...olderMessages,
          ..._visibleMessages,
        ]);
      }
    } catch (_) {
    } finally {
      _isLoadingOlderMessages = false;
      notifyListeners();
    }
  }

  void startDraftSession(String sessionId, {bool notify = true}) {
    _selectedSessionId = sessionId;
    _setVisibleMessages(const <ChatMessageRecord>[]);
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
      _setVisibleMessages(const <ChatMessageRecord>[]);
      _refreshSelectedSessionCacheFromVisibleMessages();
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
        _setVisibleMessages(fullMessages.skip(firstVisibleIndex));
        _refreshSelectedSessionCacheFromVisibleMessages();
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
    _setVisibleMessages(fullMessages.skip(fullMessages.length - targetCount));
    _refreshSelectedSessionCacheFromVisibleMessages();
    if (notify) {
      notifyListeners();
    }
  }

  void _commitLoadedMessages({
    required String sessionId,
    required int generation,
    required List<ChatMessageRecord> messages,
  }) {
    if (generation != _sessionLoadGeneration ||
        _selectedSessionId != sessionId) {
      return;
    }
    _setVisibleMessages(messages);
    _isLoadingMessages = false;
    notifyListeners();
  }

  void _setVisibleMessages(Iterable<ChatMessageRecord> messages) {
    final nextMessages = List<ChatMessageRecord>.unmodifiable(messages);
    if (_sameMessageWindow(_visibleMessages, nextMessages)) {
      return;
    }
    _visibleMessages = nextMessages;
    _visibleMessagesRevision += 1;
  }

  bool _sameMessageWindow(
    List<ChatMessageRecord> left,
    List<ChatMessageRecord> right,
  ) {
    if (identical(left, right)) {
      return true;
    }
    if (left.length != right.length) {
      return false;
    }
    for (var i = 0; i < left.length; i += 1) {
      if (!identical(left[i], right[i]) && left[i] != right[i]) {
        return false;
      }
    }
    return true;
  }

  Future<List<ChatMessageRecord>> _initialMessagesForSession(
    ChatSessionRecord session,
  ) {
    final cachedMessages = _cachedInitialMessages(session);
    if (cachedMessages != null) {
      return SynchronousFuture<List<ChatMessageRecord>>(cachedMessages);
    }

    final signature = _InitialMessageCacheSignature.fromSession(session);
    final existingLoad = _activeInitialMessageLoad(session);
    if (existingLoad != null) {
      return existingLoad.future;
    }

    final future = _repository
        .loadInitialMessages(
          session,
          minMessages: initialMessageMin,
          maxMessages: initialMessageMax,
          textBudget: initialTextBudget,
        )
        .then((messages) {
          _storeInitialMessages(session.id, signature, messages);
          return messages;
        })
        .whenComplete(() {
          final load = _preloadLoads[session.id];
          if (load?.signature == signature) {
            _preloadLoads.remove(session.id);
          }
        });
    _preloadLoads[session.id] = _InitialMessageLoad(
      signature: signature,
      future: future,
    );
    return future;
  }

  _InitialMessageLoad? _activeInitialMessageLoad(ChatSessionRecord session) {
    final load = _preloadLoads[session.id];
    if (load == null) {
      return null;
    }
    final signature = _InitialMessageCacheSignature.fromSession(session);
    if (load.signature == signature) {
      return load;
    }
    _preloadLoads.remove(session.id);
    return null;
  }

  List<ChatMessageRecord>? _cachedInitialMessages(ChatSessionRecord session) {
    final entry = _initialMessageCache.remove(session.id);
    if (entry == null) {
      return null;
    }
    if (entry.signature != _InitialMessageCacheSignature.fromSession(session)) {
      return null;
    }
    _initialMessageCache[session.id] = entry;
    return entry.messages;
  }

  void _storeInitialMessages(
    String sessionId,
    _InitialMessageCacheSignature signature,
    List<ChatMessageRecord> messages,
  ) {
    _initialMessageCache.remove(sessionId);
    _initialMessageCache[sessionId] = _InitialMessageCacheEntry(
      signature: signature,
      messages: List<ChatMessageRecord>.unmodifiable(messages),
    );
    while (_initialMessageCache.length > initialMessageCacheCapacity) {
      _initialMessageCache.remove(_initialMessageCache.keys.first);
    }
  }

  void _refreshSelectedSessionCacheFromVisibleMessages() {
    final session = selectedSession;
    if (session == null) {
      return;
    }
    _storeInitialMessages(
      session.id,
      _InitialMessageCacheSignature.fromSession(session),
      _visibleMessages.length > initialMessageMax
          ? _visibleMessages.sublist(
              _visibleMessages.length - initialMessageMax,
            )
          : _visibleMessages,
    );
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

class _InitialMessageCacheEntry {
  const _InitialMessageCacheEntry({
    required this.signature,
    required this.messages,
  });

  final _InitialMessageCacheSignature signature;
  final List<ChatMessageRecord> messages;
}

class _InitialMessageLoad {
  const _InitialMessageLoad({required this.signature, required this.future});

  final _InitialMessageCacheSignature signature;
  final Future<List<ChatMessageRecord>> future;
}

class _InitialMessageCacheSignature {
  const _InitialMessageCacheSignature({
    required this.messageCount,
    required this.lastMessageId,
    required this.updatedAt,
  });

  factory _InitialMessageCacheSignature.fromSession(ChatSessionRecord session) {
    return _InitialMessageCacheSignature(
      messageCount: session.messageIds.length,
      lastMessageId: session.messageIds.isEmpty
          ? null
          : session.messageIds.last,
      updatedAt: session.updatedAt,
    );
  }

  final int messageCount;
  final String? lastMessageId;
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _InitialMessageCacheSignature &&
            messageCount == other.messageCount &&
            lastMessageId == other.lastMessageId &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(messageCount, lastMessageId, updatedAt);
}
