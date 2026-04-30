import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/features/server/pages/model_management_page.dart';
import 'package:servllama/features/server/pages/server_config_page.dart';
import 'package:servllama/features/server/pages/server_logs_page.dart';
import 'package:servllama/l10n/l10n.dart';

class ServerPage extends StatefulWidget {
  const ServerPage({super.key});

  @override
  State<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      context.read<ServerProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _ServerCard(
              onToggle: () => context.read<ServerProvider>().toggle(),
            ),
            const SizedBox(height: 20),
            _MenuGroupCard(
              items: [
                _MenuItemData(
                  icon: Icons.tune_rounded,
                  title: l10n.serverMenuConfig,
                  onTap: () => _push(context, const ServerConfigPage()),
                ),
                _MenuItemData(
                  icon: Icons.receipt_long_rounded,
                  title: l10n.serverMenuLogs,
                  onTap: () => _push(context, const ServerLogsPage()),
                ),
                _MenuItemData(
                  icon: Icons.inventory_2_outlined,
                  title: l10n.serverMenuModels,
                  onTap: () => _push(context, const ModelManagementPage()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.onToggle});

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ServerProvider>();
    final isRunning = provider.isRunning;
    final isBusy = provider.isBusy;
    final l10n = context.l10n;
    final statusText = isRunning
        ? l10n.serverStatusRunning
        : l10n.serverStatusStopped;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return DecoratedBox(
      key: const Key('server_page_status_card'),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(110)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _StatusChip(label: statusText, isRunning: isRunning),
                const Spacer(),
                _ServerActionButton(
                  isRunning: isRunning,
                  isBusy: isBusy,
                  onPressed: isBusy ? null : onToggle,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l10n.serverBaseUrlLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            _BaseUrlPanel(
              baseUrl: provider.baseUrl,
              onCopy: () => _copyBaseUrl(context, provider.baseUrl),
            ),
            if (provider.lastError != null) ...[
              const SizedBox(height: 14),
              _ErrorMessage(message: provider.lastError!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _copyBaseUrl(BuildContext context, String baseUrl) async {
    await Clipboard.setData(ClipboardData(text: baseUrl));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.serverBaseUrlCopied)));
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.isRunning});

  final String label;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final backgroundColor = isRunning
        ? colorScheme.primaryContainer.withAlpha(isLight ? 220 : 180)
        : (isLight
              ? const Color(0xFFF1F4F9)
              : colorScheme.surfaceContainerHighest);
    final foregroundColor = isRunning
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: foregroundColor.withAlpha(220),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerActionButton extends StatelessWidget {
  const _ServerActionButton({
    required this.isRunning,
    required this.isBusy,
    required this.onPressed,
  });

  final bool isRunning;
  final bool isBusy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final icon = isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded;
    final label = isRunning ? l10n.serverStop : l10n.serverStart;

    return FilledButton.icon(
      key: const Key('server_page_toggle_button'),
      onPressed: onPressed,
      icon: isBusy
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: isRunning
                    ? colorScheme.onErrorContainer
                    : colorScheme.onPrimary,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: isRunning
            ? colorScheme.errorContainer
            : colorScheme.primary,
        foregroundColor: isRunning
            ? colorScheme.onErrorContainer
            : colorScheme.onPrimary,
        disabledBackgroundColor: isRunning
            ? colorScheme.errorContainer
            : colorScheme.primary,
        disabledForegroundColor: isRunning
            ? colorScheme.onErrorContainer
            : colorScheme.onPrimary,
        minimumSize: const Size(104, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        textStyle: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BaseUrlPanel extends StatelessWidget {
  const _BaseUrlPanel({required this.baseUrl, required this.onCopy});

  final String baseUrl;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final l10n = context.l10n;

    return DecoratedBox(
      key: const Key('server_page_base_url_panel'),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF2F4FA)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                baseUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: onCopy,
              tooltip: l10n.serverCopyBaseUrl,
              style: IconButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
                minimumSize: const Size(40, 40),
              ),
              icon: const Icon(Icons.content_copy_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuGroupCard extends StatelessWidget {
  const _MenuGroupCard({required this.items});

  final List<_MenuItemData> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return DecoratedBox(
      key: const Key('server_page_menu_group'),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(110)),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            _MenuCard(item: items[index]),
            if (index != items.length - 1)
              Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: colorScheme.outlineVariant.withAlpha(90),
              ),
          ],
        ],
      ),
    );
  }
}

class _MenuCard extends StatefulWidget {
  const _MenuCard({required this.item});

  final _MenuItemData item;

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value || !mounted) {
      return;
    }
    setState(() {
      _isPressed = value;
    });
  }

  void _handleTap() {
    _setPressed(false);
    widget.item.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final contentOpacity = _isPressed ? 0.58 : 1.0;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: _handleTap,
        child: AnimatedOpacity(
          key: ValueKey<String>('server_page_menu_item_${widget.item.title}'),
          opacity: contentOpacity,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Icon(
                    widget.item.icon,
                    size: 22,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.item.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}
