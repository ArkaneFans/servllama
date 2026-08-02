import 'package:flutter/material.dart';
import 'package:servllama/app/app_palette.dart';
import 'package:servllama/core/models/inference_engine.dart';

/// Small colored chip identifying which engine a model or runtime belongs to.
/// The label is always present — color alone never carries the meaning.
class EngineBadge extends StatelessWidget {
  const EngineBadge({super.key, required this.engine, this.compact = false});

  final InferenceEngine engine;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.palette.engineColor(engine);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(theme.brightness == Brightness.light ? 28 : 46),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 6 : 7,
            height: compact ? 6 : 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 5 : 6),
          Text(
            engine.displayName,
            style: (compact ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Square badge used on model cards, showing the storage format rather than
/// the engine name — that is what the user sees on disk.
class ModelFormatBadge extends StatelessWidget {
  const ModelFormatBadge({super.key, required this.engine, this.size = 44});

  final InferenceEngine engine;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.palette.engineColor(engine);
    final label = engine == InferenceEngine.mnn ? 'MNN' : 'GGUF';

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withAlpha(theme.brightness == Brightness.light ? 28 : 46),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.22,
        ),
      ),
    );
  }
}

enum StatusTone { ok, warning, danger, idle }

/// Status pill: dot + label. Never colour-only, so it stays readable for
/// users who cannot separate the hues.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final (Color mark, Color text) = switch (tone) {
      StatusTone.ok => (palette.okMark, palette.okText),
      StatusTone.warning => (palette.warningMark, palette.warningText),
      StatusTone.danger => (palette.dangerMark, palette.dangerText),
      StatusTone.idle => (palette.idleMark, theme.colorScheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: mark.withAlpha(theme.brightness == Brightness.light ? 26 : 44),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: mark, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline notice strip used for constraints the user must know before acting
/// (MNN restarts on model swap, unverified search results, and so on).
class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.message,
    this.tone = StatusTone.warning,
    this.icon,
  });

  final String message;
  final StatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.palette;
    final (Color mark, Color text) = switch (tone) {
      StatusTone.ok => (palette.okMark, palette.okText),
      StatusTone.warning => (palette.warningMark, palette.warningText),
      StatusTone.danger => (palette.dangerMark, palette.dangerText),
      StatusTone.idle => (
        palette.idleMark,
        theme.colorScheme.onSurfaceVariant,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: mark.withAlpha(theme.brightness == Brightness.light ? 22 : 38),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? Icons.info_outline_rounded, size: 18, color: mark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: text,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
