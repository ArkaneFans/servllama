import 'package:flutter/foundation.dart';

/// Resolved identity for the chat input bar's model selector button.
///
/// Carries just enough for [AiIdentityIcon] to pick a brand glyph — the model
/// name for family matching, whether it is a local runtime model, and the
/// owning connection's identity as a provider fallback. The input bar owns the
/// fallback icon when this is null (no target selected).
@immutable
class ChatModelIconData {
  const ChatModelIconData({
    required this.model,
    required this.local,
    this.providerId,
    this.providerName,
  });

  final String model;
  final bool local;
  final String? providerId;
  final String? providerName;

  @override
  bool operator ==(Object other) =>
      other is ChatModelIconData &&
      other.model == model &&
      other.local == local &&
      other.providerId == providerId &&
      other.providerName == providerName;

  @override
  int get hashCode => Object.hash(model, local, providerId, providerName);
}
