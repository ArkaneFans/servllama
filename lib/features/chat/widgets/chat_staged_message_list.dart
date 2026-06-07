import 'package:flutter/material.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';

typedef ChatStagedMessageListBuilder =
    Widget Function(BuildContext context, List<ChatMessageRecord> messages);

class ChatStagedMessageList extends StatefulWidget {
  const ChatStagedMessageList({
    super.key,
    required this.conversationKey,
    required this.messages,
    required this.builder,
    this.onSettled,
  });

  static const int directMessageCount = 12;
  static const int directTextBudget = 12000;
  static const int stagedMessageCount = 8;
  static const int stagedTextBudget = 6000;
  static const int imageWeight = 1200;

  final String conversationKey;
  final List<ChatMessageRecord> messages;
  final ChatStagedMessageListBuilder builder;
  final ValueChanged<String>? onSettled;

  @override
  State<ChatStagedMessageList> createState() => _ChatStagedMessageListState();
}

class _ChatStagedMessageListState extends State<ChatStagedMessageList> {
  late List<ChatMessageRecord> _displayedMessages;
  bool _isStaged = false;
  int _settleGeneration = 0;

  @override
  void initState() {
    super.initState();
    _restartStage();
  }

  @override
  void didUpdateWidget(covariant ChatStagedMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final conversationChanged =
        oldWidget.conversationKey != widget.conversationKey;
    final messagesChanged = !_sameMessageWindow(
      oldWidget.messages,
      widget.messages,
    );
    if (!conversationChanged && !messagesChanged) {
      return;
    }

    if (conversationChanged || _isStaged) {
      _restartStage();
    } else {
      _settleGeneration += 1;
      _isStaged = false;
      _displayedMessages = _copyMessages(widget.messages);
    }
  }

  void _restartStage() {
    _settleGeneration += 1;
    final generation = _settleGeneration;
    final initialMessages = _initialMessagesFor(widget.messages);
    _displayedMessages = initialMessages;
    _isStaged = initialMessages.length != widget.messages.length;
    if (_isStaged) {
      _scheduleSettle(generation);
    }
  }

  void _scheduleSettle(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _settleGeneration) {
        return;
      }
      setState(() {
        _isStaged = false;
        _displayedMessages = _copyMessages(widget.messages);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _settleGeneration) {
          return;
        }
        widget.onSettled?.call(widget.conversationKey);
      });
    });
  }

  List<ChatMessageRecord> _initialMessagesFor(
    List<ChatMessageRecord> messages,
  ) {
    if (!_needsStaging(messages)) {
      return _copyMessages(messages);
    }

    var start = messages.length;
    var weight = 0;
    var included = 0;
    while (start > 0 && included < ChatStagedMessageList.stagedMessageCount) {
      if (included > 0 && weight >= ChatStagedMessageList.stagedTextBudget) {
        break;
      }
      start -= 1;
      included += 1;
      weight += _estimateMessageWeight(messages[start]);
    }
    return messages.sublist(start).toList(growable: false);
  }

  bool _needsStaging(List<ChatMessageRecord> messages) {
    if (messages.isEmpty) {
      return false;
    }
    if (messages.length > ChatStagedMessageList.directMessageCount) {
      return true;
    }
    var weight = 0;
    for (final message in messages) {
      weight += _estimateMessageWeight(message);
      if (weight > ChatStagedMessageList.directTextBudget) {
        return true;
      }
    }
    return false;
  }

  int _estimateMessageWeight(ChatMessageRecord message) {
    final contentLength = message.content.length;
    final contentWeight = message.role == ChatRole.user
        ? (contentLength < 200 ? 200 : contentLength)
        : (contentLength * 0.8).round();
    final reasoningWeight = ((message.reasoningContent?.length ?? 0) * 0.8)
        .round();
    return contentWeight +
        reasoningWeight +
        message.imageFilePaths.length * ChatStagedMessageList.imageWeight;
  }

  List<ChatMessageRecord> _copyMessages(List<ChatMessageRecord> messages) {
    return List<ChatMessageRecord>.from(messages, growable: false);
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
      final leftMessage = left[i];
      final rightMessage = right[i];
      if (leftMessage.id != rightMessage.id ||
          leftMessage.content != rightMessage.content ||
          leftMessage.reasoningContent != rightMessage.reasoningContent ||
          leftMessage.currentVersionIndex != rightMessage.currentVersionIndex ||
          leftMessage.versionIds.length != rightMessage.versionIds.length ||
          leftMessage.imageFilePaths.length !=
              rightMessage.imageFilePaths.length) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: _isStaged,
      child: widget.builder(context, _displayedMessages),
    );
  }
}
