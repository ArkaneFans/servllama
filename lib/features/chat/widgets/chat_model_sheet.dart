import 'package:flutter/material.dart';
import 'package:servllama/features/chat/models/chat_model_option.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';

class ChatModelSheetContent extends StatelessWidget {
  const ChatModelSheetContent({
    super.key,
    required this.provider,
    required this.onRefresh,
    required this.children,
  });

  final ChatProvider provider;
  final VoidCallback onRefresh;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showInitialLoading =
        provider.isRefreshingModels && provider.models.isEmpty;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Text(l10n.chatSelectModel, style: titleStyle),
              const Spacer(),
              IconButton(
                onPressed: provider.isRefreshingModels ? null : onRefresh,
                tooltip: l10n.chatRefreshModels,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (showInitialLoading)
          const SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(
                key: Key('chat_model_sheet_loading_indicator'),
              ),
            ),
          )
        else
          ...children,
      ],
    );
  }
}

class ChatModelSection extends StatelessWidget {
  const ChatModelSection({
    super.key,
    required this.title,
    required this.models,
    required this.currentModelId,
    required this.loadingModelId,
    required this.onTap,
    this.onSecondaryAction,
  });

  final String title;
  final List<ChatModelOption> models;
  final String? currentModelId;
  final String? loadingModelId;
  final ValueChanged<ChatModelOption>? onTap;
  final ValueChanged<ChatModelOption>? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (models.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant.withAlpha(170),
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...models.map((model) {
          final isBusy = loadingModelId == model.id;
          final isSelected = currentModelId == model.id;
          return Material(
            color: isSelected
                ? colorScheme.primaryContainer.withAlpha(40)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap == null || isBusy ? null : () => onTap!(model),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        model.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (onSecondaryAction != null && model.isLoaded)
                      IconButton(
                        key: Key('chat_model_unload_button_${model.id}'),
                        tooltip: l10n.chatUnloadModel,
                        onPressed: isBusy
                            ? null
                            : () => onSecondaryAction!(model),
                        icon: const Icon(Icons.eject_outlined, size: 18),
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                      ),
                    const SizedBox(width: 4),
                    _StatusDot(isBusy: isBusy, isLoaded: model.isLoaded),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isBusy, required this.isLoaded});

  final bool isBusy;
  final bool isLoaded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (isBusy) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLoaded ? const Color(0xFF10B981) : colorScheme.outlineVariant,
      ),
    );
  }
}
