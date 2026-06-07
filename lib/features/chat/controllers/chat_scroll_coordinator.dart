import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:servllama/features/chat/controllers/chat_auto_follow_scroll_controller.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';

class ChatScrollCoordinator extends ChangeNotifier {
  ChatScrollCoordinator() {
    scrollController.shouldAutoFollow = _shouldAutoFollow;
    scrollController.addListener(_handleScroll);
  }

  static const double _autoFollowResumeThreshold = 24;
  static const double _bottomStickThreshold = 72;

  final ChatAutoFollowScrollController scrollController =
      ChatAutoFollowScrollController();

  ChatProvider? _provider;
  int _lastMessageCount = 0;
  String? _lastSelectedSessionId;
  bool _wasLoadingMessages = false;
  bool _isLoadingOlderFromScroll = false;
  bool _autoStickToBottom = true;
  bool _isScrollToBottomScheduled = false;
  bool _showJumpToLatestButton = false;
  bool _isUserScrollActive = false;
  bool _isDisposed = false;
  Timer? _userScrollActivityTimer;
  Timer? _sessionSwitchScrollTimer;
  String? _pendingSessionSwitchScrollSessionId;

  bool get showJumpToLatestButton => _showJumpToLatestButton;

  void attachProvider(ChatProvider provider) {
    if (identical(provider, _provider)) {
      return;
    }
    _provider?.streamingMessages.removeListener(_handleStreamingMessageChanged);
    _provider?.removeListener(_handleProviderChanged);
    _provider = provider;
    _lastMessageCount = provider.visibleMessages.length;
    _lastSelectedSessionId = provider.selectedSession?.id;
    _wasLoadingMessages = provider.isLoadingMessages;
    provider.addListener(_handleProviderChanged);
    provider.streamingMessages.addListener(_handleStreamingMessageChanged);
  }

  void enableAutoStickToBottom({bool hideJumpButton = true}) {
    _clearUserScrollActivity();
    _autoStickToBottom = true;
    if (hideJumpButton) {
      _setShowJumpToLatestButton(false);
    }
  }

  void jumpToLatestMessage() {
    enableAutoStickToBottom(hideJumpButton: false);
    _scrollToBottom();
  }

  bool handleMessageScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _handleUserScrollActivity(notification.metrics);
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      _handleUserScrollActivity(notification.metrics);
    } else if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _handleUserScrollActivity(notification.metrics);
    } else if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.idle) {
        _scheduleUserScrollIdle();
      } else {
        _handleUserScrollActivity(notification.metrics);
      }
    } else if (notification is ScrollEndNotification) {
      _scheduleUserScrollIdle();
    }

    if (_isMetricsNearBottom(
      notification.metrics,
      _autoFollowResumeThreshold,
    )) {
      _autoStickToBottom = true;
      _setShowJumpToLatestButton(false);
    } else if (_isUserScrollActive) {
      _autoStickToBottom = false;
      _setShowJumpToLatestButton(_hasVisibleMessageList);
    } else if (_isMetricsNearBottom(notification.metrics)) {
      _setShowJumpToLatestButton(false);
    } else if (!_autoStickToBottom) {
      _setShowJumpToLatestButton(_hasVisibleMessageList);
    }
    return false;
  }

  void handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _handleUserScrollActivity();
    }
  }

  bool _shouldAutoFollow() {
    return !_isDisposed &&
        _autoStickToBottom &&
        !_isUserScrollActive &&
        !_isLoadingOlderFromScroll;
  }

  void _handleProviderChanged() {
    final provider = _provider;
    if (provider == null) {
      return;
    }

    final selectedSessionId = provider.selectedSession?.id;
    if (selectedSessionId != _lastSelectedSessionId) {
      _lastSelectedSessionId = selectedSessionId;
      _lastMessageCount = provider.visibleMessages.length;
      _isLoadingOlderFromScroll = false;
      _pendingSessionSwitchScrollSessionId = selectedSessionId;
      enableAutoStickToBottom();
      _setShowJumpToLatestButton(false);
    }

    final finishedLoadingMessages =
        _wasLoadingMessages && !provider.isLoadingMessages;
    _wasLoadingMessages = provider.isLoadingMessages;
    if (finishedLoadingMessages &&
        selectedSessionId != null &&
        _pendingSessionSwitchScrollSessionId == selectedSessionId) {
      _pendingSessionSwitchScrollSessionId = null;
      _scheduleSessionSwitchScrollToBottom();
    }
    final shouldAutoScroll = _autoStickToBottom || _isNearBottom();
    final count = provider.visibleMessages.length;
    final countIncreased = count > _lastMessageCount;
    _lastMessageCount = count;

    if (!finishedLoadingMessages && shouldAutoScroll && countIncreased) {
      _scheduleScrollToBottom();
    }
  }

  void _handleScroll() {
    if (!_hasSingleScrollPosition) {
      return;
    }
    if (_isNearBottom(_autoFollowResumeThreshold)) {
      _autoStickToBottom = true;
      _setShowJumpToLatestButton(false);
    } else if (_isUserScrollActive) {
      _autoStickToBottom = false;
      _setShowJumpToLatestButton(_hasVisibleMessageList);
    } else if (!_isNearBottom(_bottomStickThreshold)) {
      _setShowJumpToLatestButton(_hasVisibleMessageList);
    }

    final provider = _provider;
    if (provider == null ||
        _isLoadingOlderFromScroll ||
        provider.isLoadingMessages ||
        provider.isLoadingOlderMessages ||
        !provider.hasOlderMessages) {
      return;
    }
    if (scrollController.position.pixels <= 96) {
      unawaited(_loadOlderMessagesPreservingOffset(provider));
    }
  }

  bool _isNearBottom([double threshold = _bottomStickThreshold]) {
    if (!_hasSingleScrollPosition) {
      return true;
    }
    final position = scrollController.position;
    return position.maxScrollExtent - position.pixels <= threshold;
  }

  bool get _hasSingleScrollPosition {
    return scrollController.hasClients &&
        scrollController.positions.length == 1;
  }

  bool _isMetricsNearBottom(
    ScrollMetrics metrics, [
    double threshold = _bottomStickThreshold,
  ]) {
    return metrics.maxScrollExtent - metrics.pixels <= threshold;
  }

  void _handleUserScrollActivity([ScrollMetrics? metrics]) {
    _isUserScrollActive = true;
    if (metrics == null
        ? _isNearBottom(_autoFollowResumeThreshold)
        : _isMetricsNearBottom(metrics, _autoFollowResumeThreshold)) {
      _autoStickToBottom = true;
      _setShowJumpToLatestButton(false);
    } else {
      _autoStickToBottom = false;
      _setShowJumpToLatestButton(_hasVisibleMessageList);
    }
    _scheduleUserScrollIdle();
  }

  void _scheduleUserScrollIdle() {
    _userScrollActivityTimer?.cancel();
    _userScrollActivityTimer = Timer(const Duration(milliseconds: 180), () {
      if (_isDisposed) {
        return;
      }
      _isUserScrollActive = false;
      if (_isNearBottom(_autoFollowResumeThreshold)) {
        _autoStickToBottom = true;
        _setShowJumpToLatestButton(false);
      }
    });
  }

  void _clearUserScrollActivity() {
    _userScrollActivityTimer?.cancel();
    _userScrollActivityTimer = null;
    _isUserScrollActive = false;
  }

  void _handleStreamingMessageChanged() {
    if (_isDisposed) {
      return;
    }
    if (_autoStickToBottom || _isNearBottom(_autoFollowResumeThreshold)) {
      _autoStickToBottom = true;
      _setShowJumpToLatestButton(false);
      return;
    }
    _setShowJumpToLatestButton(_hasVisibleMessageList);
  }

  bool get _hasVisibleMessageList {
    final provider = _provider;
    return provider != null &&
        !provider.isLoadingMessages &&
        provider.visibleMessages.isNotEmpty;
  }

  void _scheduleScrollToBottom({int remainingRetries = 0}) {
    if (_isScrollToBottomScheduled) {
      return;
    }
    _isScrollToBottomScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isScrollToBottomScheduled = false;
      if (_isDisposed) {
        return;
      }
      if (_autoStickToBottom || _isNearBottom()) {
        _scrollToBottom(remainingRetries: remainingRetries);
      }
    });
  }

  void _scrollToBottom({int remainingRetries = 0}) {
    if (!scrollController.hasClients) {
      return;
    }
    if (!_hasSingleScrollPosition) {
      if (remainingRetries > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isDisposed) {
            return;
          }
          _scrollToBottom(remainingRetries: remainingRetries - 1);
        });
      }
      return;
    }
    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    if (_isNearBottom()) {
      _setShowJumpToLatestButton(false);
    }
  }

  void _scheduleSessionSwitchScrollToBottom() {
    _sessionSwitchScrollTimer?.cancel();
    enableAutoStickToBottom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed) {
        return;
      }
      enableAutoStickToBottom();
      _scrollToBottom(remainingRetries: 1);
    });
    _sessionSwitchScrollTimer = Timer(const Duration(milliseconds: 220), () {
      _sessionSwitchScrollTimer = null;
      if (_isDisposed) {
        return;
      }
      enableAutoStickToBottom();
      _scrollToBottom(remainingRetries: 1);
    });
  }

  void _setShowJumpToLatestButton(bool value) {
    if (_isDisposed || _showJumpToLatestButton == value) {
      return;
    }
    _showJumpToLatestButton = value;
    notifyListeners();
  }

  Future<void> _loadOlderMessagesPreservingOffset(ChatProvider provider) async {
    if (!_hasSingleScrollPosition || _isLoadingOlderFromScroll) {
      return;
    }
    _isLoadingOlderFromScroll = true;
    _autoStickToBottom = false;
    final sessionId = provider.selectedSession?.id;
    final position = scrollController.position;
    final previousMaxScrollExtent = position.maxScrollExtent;
    final previousPixels = position.pixels;

    await provider.loadOlderMessages();
    if (_isDisposed) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isLoadingOlderFromScroll = false;
      if (_isDisposed ||
          !_hasSingleScrollPosition ||
          _provider?.selectedSession?.id != sessionId) {
        return;
      }
      final position = scrollController.position;
      final targetPixels =
          previousPixels + position.maxScrollExtent - previousMaxScrollExtent;
      scrollController.jumpTo(
        targetPixels.clamp(0.0, position.maxScrollExtent),
      );
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _provider?.streamingMessages.removeListener(_handleStreamingMessageChanged);
    _provider?.removeListener(_handleProviderChanged);
    _provider = null;
    scrollController.removeListener(_handleScroll);
    scrollController.dispose();
    _userScrollActivityTimer?.cancel();
    _sessionSwitchScrollTimer?.cancel();
    super.dispose();
  }
}
