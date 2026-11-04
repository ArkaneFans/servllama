import 'package:flutter/material.dart';
import 'package:servllama/features/chat/models/chat_context_usage.dart';
import 'package:servllama/l10n/l10n.dart';

/// A 32 dp ring inside a full 48 dp touch target, at the composer's far right.
class ChatContextUsageRing extends StatelessWidget {
  const ChatContextUsageRing({
    super.key,
    this.usage = const ChatContextUsage(),
  });

  final ChatContextUsage usage;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final fraction = usage.fraction;
    final color = fraction == null
        ? colors.onSurfaceVariant
        : fraction >= .95
        ? colors.error
        : fraction >= .8
        ? colors.tertiary
        : colors.primary;
    final label = '${l.chatContextUsage}: ${usage.percentageLabel}';
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: InkResponse(
          key: const Key('chat_context_usage_button'),
          onTap: () => _showDetails(context),
          radius: 24,
          containedInkWell: true,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: SizedBox.square(
                dimension: 32,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        key: const Key('chat_context_usage_progress'),
                        value: usage.progress,
                        strokeWidth: 2.5,
                        backgroundColor: colors.outlineVariant,
                        color: color,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(5),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          usage.percentageLabel,
                          key: const Key('chat_context_usage_percentage'),
                          maxLines: 1,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final l = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.chatContextUsage,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                l.chatContextTokens(
                  usage.usedTokens?.toString() ?? '-',
                  usage.capacityTokens?.toString() ?? '-',
                ),
                key: const Key('chat_context_usage_details'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                usage.usedTokens == null
                    ? l.chatContextUnavailable
                    : l.chatContextActual,
              ),
              const SizedBox(height: 8),
              Text(
                usage.usedTokens == null
                    ? l.chatContextChanged
                    : l.chatContextActualNote,
              ),
              const SizedBox(height: 8),
              Text(
                usage.capacityTokens == null
                    ? l.chatContextUnknownCapacity
                    : l.chatContextBackendCapacity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
