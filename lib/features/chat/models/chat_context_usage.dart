import 'package:servllama/features/chat/models/chat_message_record.dart';

/// Only backend-observed counts are admitted here. Unknown is not zero, and
/// cumulative billing totals or character-based estimates are never context.
class ChatContextUsage {
  const ChatContextUsage({int? usedTokens, this.capacityTokens})
    : _usedTokens = usedTokens;

  final int? _usedTokens;

  // Prompt+output usage beyond the active capacity can indicate context shift
  // or truncation. It does not prove retained occupancy, so show unknown.
  int? get usedTokens =>
      _usedTokens == null ||
          _usedTokens < 0 ||
          (capacityTokens != null &&
              capacityTokens! > 0 &&
              _usedTokens > capacityTokens!)
      ? null
      : _usedTokens;
  final int? capacityTokens;

  bool get hasPercentage =>
      usedTokens != null &&
      usedTokens! >= 0 &&
      capacityTokens != null &&
      capacityTokens! > 0;

  double? get fraction => hasPercentage ? usedTokens! / capacityTokens! : null;

  /// The drawing is bounded; unprovable overflow is unknown, never 100%+.
  double get progress => fraction?.clamp(0.0, 1.0) ?? 0;
  String get percentageLabel =>
      hasPercentage ? '${(fraction! * 100).round()}%' : '-';

  /// A measurement belongs to the latest response and its exact input prefix.
  /// Earlier responses cannot stand in for an edited/retried/new conversation.
  static int? currentTokens({
    required List<ChatMessageRecord> messages,
    required String modelId,
    required String connectionId,
    required String expectedContextKey,
    bool hasDraft = false,
    bool isSending = false,
  }) {
    if (hasDraft || isSending || messages.isEmpty) return null;
    final last = messages.last;
    final metrics = last.generationMetrics;
    if (last.role != ChatRole.assistant ||
        metrics == null ||
        metrics.modelId != modelId ||
        metrics.connectionId != connectionId ||
        metrics.contextKey == null ||
        metrics.contextKey != expectedContextKey) {
      return null;
    }
    return metrics.contextTokens;
  }
}
