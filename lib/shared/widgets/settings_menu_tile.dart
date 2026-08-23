import 'package:flutter/material.dart';

/// A single setting row that matches the app's standard settings tile:
/// a 24px icon box, a `titleMedium` w700 title, an optional trailing value
/// and chevron (when [onTap] is set), or an arbitrary [trailing] widget
/// (e.g. a switch) when no chevron is wanted.
///
/// Extracted from the private `_MenuTile` so the download section can share
/// the exact same typography, spacing and press animation as the rest of the
/// settings page.
class SettingsMenuTile extends StatefulWidget {
  const SettingsMenuTile({
    super.key,
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
    this.trailing,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? value;

  /// When non-null, this widget is shown on the right instead of the value
  /// text + chevron. Use it for in-row controls such as switches.
  final Widget? trailing;

  /// When null and [trailing] is null, the tile is non-interactive and shows
  /// no chevron. When set, the whole row is tappable and a chevron is shown
  /// (unless [trailing] overrides the trailing slot).
  final VoidCallback? onTap;

  final bool enabled;

  @override
  State<SettingsMenuTile> createState() => _SettingsMenuTileState();
}

class _SettingsMenuTileState extends State<SettingsMenuTile> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value || !mounted) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final contentOpacity = _isPressed ? 0.58 : 1.0;
    final effectiveOnTap = widget.enabled ? widget.onTap : null;

    return Semantics(
      button: effectiveOnTap != null,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: effectiveOnTap,
        child: AnimatedOpacity(
          opacity: widget.enabled ? contentOpacity : 0.5,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Icon(
                  widget.icon,
                  size: 22,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 12),
                widget.trailing!,
              ] else if (widget.value != null) ...[
                const SizedBox(width: 12),
                Text(
                  widget.value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              if (widget.trailing == null && effectiveOnTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
