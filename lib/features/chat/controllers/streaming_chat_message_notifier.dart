import 'package:flutter/foundation.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';

@immutable
class StreamingChatMessageData {
  const StreamingChatMessageData({
    required this.message,
    required this.isStreaming,
  });

  final ChatMessageRecord message;
  final bool isStreaming;
}

class StreamingChatMessageNotifier extends ChangeNotifier {
  final Map<String, ValueNotifier<StreamingChatMessageData>> _notifiers =
      <String, ValueNotifier<StreamingChatMessageData>>{};

  bool hasNotifier(String messageId) => _notifiers.containsKey(messageId);

  ValueNotifier<StreamingChatMessageData> getNotifier(
    ChatMessageRecord message,
  ) {
    return _notifiers.putIfAbsent(
      message.id,
      () => ValueNotifier<StreamingChatMessageData>(
        StreamingChatMessageData(message: message, isStreaming: true),
      ),
    );
  }

  ValueListenable<StreamingChatMessageData>? listenableFor(String messageId) {
    return _notifiers[messageId];
  }

  void update(ChatMessageRecord message, {required bool isStreaming}) {
    final notifier = getNotifier(message);
    notifier.value = StreamingChatMessageData(
      message: message,
      isStreaming: isStreaming,
    );
    notifyListeners();
  }

  /// Detaches a finished streaming entry so the bubble renders from the
  /// persisted record again. The removed ValueNotifier is intentionally not
  /// disposed here: a ValueListenableBuilder may still be subscribed until
  /// the next rebuild, and an unreferenced notifier is simply collected.
  void remove(String messageId) {
    if (_notifiers.remove(messageId) == null) {
      return;
    }
    notifyListeners();
  }

  void clear() {
    for (final notifier in _notifiers.values) {
      notifier.dispose();
    }
    _notifiers.clear();
  }

  @override
  void dispose() {
    clear();
    super.dispose();
  }
}
