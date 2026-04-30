import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/providers/server_provider.dart';
import 'package:servllama/features/settings/pages/settings_page.dart';
import 'package:servllama/features/chat/pages/chat_page.dart';
import 'package:servllama/features/chat/pages/chat_history_page.dart';
import 'package:servllama/features/chat/widgets/chat_session_search_field.dart';
import 'package:servllama/features/chat/widgets/chat_session_drawer_section.dart';
import 'package:servllama/features/server/pages/server_page.dart';
import 'package:servllama/l10n/l10n.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  void _closeDrawer() {
    Navigator.of(context).pop();
  }

  Future<void> _pushFromDrawer(Widget page) async {
    final navigator = Navigator.of(context);
    await navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _pushHistoryPage() async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ChatHistoryPage(onSessionOpened: _closeDrawer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final colorScheme = theme.colorScheme;
    final serverProvider = context.watch<ServerProvider?>();

    return Scaffold(
      body: ChatPage(
        onNavigateToServer: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ServerPage()));
        },
      ),
      drawer: Drawer(
        width: 300,
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 5),
                child: Row(
                  children: [
                    const Expanded(child: _DrawerSearchBox()),
                    const SizedBox(width: 12),
                    _DrawerCircleButton(
                      key: const Key('drawer_history_button'),
                      icon: Icons.history_rounded,
                      tooltip: l10n.drawerAllHistoryTooltip,
                      onPressed: _pushHistoryPage,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ChatSessionDrawerSection(
                  presentationContext: context,
                  isChatSelected: true,
                  onOpenChat: _closeDrawer,
                ),
              ),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withAlpha(120),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                child: Column(
                  children: [
                    _DrawerActionBlock(
                      key: const Key('drawer_server_action'),
                      icon: Icons.dns_outlined,
                      title: l10n.drawerServer,
                      showStatusBadge: true,
                      isOnline: serverProvider?.isRunning == true,
                      onTap: () => _pushFromDrawer(const ServerPage()),
                    ),
                    const SizedBox(height: 8),
                    _DrawerActionBlock(
                      key: const Key('drawer_settings_action'),
                      icon: Icons.settings_outlined,
                      title: l10n.drawerSettings,
                      onTap: () => _pushFromDrawer(const SettingsPage()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerSearchBox extends StatelessWidget {
  const _DrawerSearchBox();

  @override
  Widget build(BuildContext context) {
    return ChatSessionSearchField(
      key: const Key('drawer_search_box'),
      fieldKey: const Key('drawer_search_input'),
      hintText: context.l10n.chatSearchHint,
    );
  }
}

class _DrawerCircleButton extends StatelessWidget {
  const _DrawerCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurfaceVariant,
        hoverColor: colorScheme.surfaceContainerLow,
        highlightColor: colorScheme.surfaceContainerLow,
      ),
      icon: Icon(icon, size: 26),
    );
  }
}

class _DrawerActionBlock extends StatefulWidget {
  const _DrawerActionBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.showStatusBadge = false,
    this.isOnline = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool showStatusBadge;
  final bool isOnline;

  @override
  State<_DrawerActionBlock> createState() => _DrawerActionBlockState();
}

class _DrawerActionBlockState extends State<_DrawerActionBlock> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed == value || !mounted) return;
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderColor = colorScheme.outlineVariant.withAlpha(120);
    final iconColor = colorScheme.onSurfaceVariant;
    final contentOpacity = _isPressed ? 0.58 : 1.0;

    return Semantics(
      button: true,
      enabled: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedOpacity(
          opacity: contentOpacity,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(widget.icon, size: 22, color: iconColor),
                      ),
                      if (widget.showStatusBadge)
                        Positioned(
                          right: 8,
                          bottom: -1,
                          child: Container(
                            key: const Key('drawer_server_status_badge'),
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: widget.isOnline
                                  ? const Color(0xFF10B981)
                                  : colorScheme.outlineVariant,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.surfaceContainerLowest,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onSurfaceVariant.withAlpha(180),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
