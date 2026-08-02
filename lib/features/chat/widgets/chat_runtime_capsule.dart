import 'package:flutter/material.dart';
import 'package:servllama/app/app_palette.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

/// Compact, always-visible runtime entry in the chat app bar. It keeps the
/// engine, resident model and service state one tap away without exposing
/// implementation details such as ports or process controls.
class ChatRuntimeCapsule extends StatelessWidget {
  const ChatRuntimeCapsule({
    super.key,
    required this.state,
    required this.label,
    required this.onTap,
  });

  final EngineRuntimeState state;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mark = switch (state.status) {
      EngineRuntimeStatus.ready => theme.palette.okMark,
      EngineRuntimeStatus.preparing ||
      EngineRuntimeStatus.stopping => theme.palette.warningMark,
      EngineRuntimeStatus.error => theme.palette.dangerMark,
      EngineRuntimeStatus.idle => theme.palette.idleMark,
    };

    return Material(
      key: const Key('chat_runtime_capsule'),
      color: colorScheme.surfaceContainerHigh,
      shape: const StadiumBorder(),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 4, 10, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              EngineBadge(engine: state.engine, compact: true),
              const SizedBox(width: 7),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: mark, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more_rounded,
                size: 17,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
