import 'package:servllama/shared/widgets/app_message.dart';
import 'package:servllama/features/design_preview/ui_primitives_page.dart';
import 'package:servllama/app/bootstrap/migration_preview_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/features/chat/pages/chat_history_page.dart';
import 'package:servllama/features/chat/pages/chat_page.dart';
import 'package:servllama/features/chat/widgets/chat_session_drawer_section.dart';
import 'package:servllama/features/chat/widgets/chat_session_search_field.dart';
import 'package:servllama/app/model_library_page.dart';
import 'package:servllama/features/assistants/pages/assistants_page.dart';
import 'package:servllama/features/assistants/widgets/assistant_selector.dart';
import 'package:servllama/features/speech/pages/speech_page.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/server/pages/server_page.dart';
import 'package:servllama/features/settings/pages/settings_page.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/push_sidebar.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final PushSidebarController _sidebarController = PushSidebarController();
  double _embeddedSidebarWidth = 300;

  Future<void> _closeSidebar() {
    return _sidebarController.close();
  }

  Future<void> _toggleSidebar() {
    return _sidebarController.toggle();
  }

  Future<void> _pushFromSidebar(Widget page) async {
    final navigator = Navigator.of(context);
    await navigator.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _pushHistoryPage() async {
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ChatHistoryPage(
          onSessionOpened: () {
            if (_sidebarController.isDrawerMode) {
              _closeSidebar();
            }
          },
        ),
      ),
    );
  }

  Future<void> _handleSessionOpened() {
    if (_sidebarController.isDrawerMode) {
      return _closeSidebar();
    }
    return Future<void>.value();
  }

  void _handleSidebarWidthChanged(double width) {
    setState(() {
      _embeddedSidebarWidth = width;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final colorScheme = theme.colorScheme;
    final serverProvider = context.watch<EngineRuntimeProvider?>();
    final downloadProvider = context.watch<DownloadProvider?>();

    return _DownloadCompletedListener(
      child: Scaffold(
        body: PushSidebar(
          controller: _sidebarController,
          semanticLabel: l10n.appTitle,
          drawerWidth: 300,
          maxScrimOpacity: 0.15,
          embeddedSidebarWidth: _embeddedSidebarWidth,
          onSidebarWidthChanged: _handleSidebarWidthChanged,
          onSidebarWidthChangeEnd: _handleSidebarWidthChanged,
          drawer: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLowest,
            ),
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
                      onOpenChat: _handleSessionOpened,
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: colorScheme.outlineVariant.withAlpha(120),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Tooltip(
                                message: l10n.uiLabTitle,
                                child: TextButton(
                                  key: const Key('drawer_ui_primitives'),
                                  onPressed: () => _pushFromSidebar(
                                    const UiPrimitivesPage(),
                                  ),
                                  child: Text(
                                    l10n.uiLabTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Tooltip(
                                message: l10n.migrationPreviewTitle,
                                child: TextButton(
                                  key: const Key('drawer_migration_preview'),
                                  onPressed: () => _pushFromSidebar(
                                    const MigrationPreviewPage(),
                                  ),
                                  child: Text(
                                    l10n.migrationPreviewTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const AssistantSelector(),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          spacing: 4,
                          runSpacing: 8,
                          children: [
                            _DrawerActionButton(
                              key: const Key('drawer_assistants_action'),
                              icon: Icons.smart_toy_outlined,
                              tooltip: l10n.drawerAssistantSettings,
                              onPressed: () =>
                                  _pushFromSidebar(const AssistantsPage()),
                            ),
                            _DrawerActionButton(
                              key: const Key('drawer_server_action'),
                              icon: Icons.dns_outlined,
                              tooltip: l10n.drawerServer,
                              statusOnline: serverProvider?.isRunning == true,
                              onPressed: () =>
                                  _pushFromSidebar(const ServerPage()),
                            ),
                            _DrawerActionButton(
                              key: const Key('drawer_models_action'),
                              icon: Icons.inventory_2_outlined,
                              tooltip: l10n.modelLibraryTitle,
                              count: downloadProvider?.activeTaskCount ?? 0,
                              onPressed: () =>
                                  _pushFromSidebar(const ModelLibraryPage()),
                            ),
                            _DrawerActionButton(
                              key: const Key('drawer_speech_action'),
                              icon: Icons.graphic_eq_rounded,
                              tooltip: l10n.v2Speech,
                              onPressed: () =>
                                  _pushFromSidebar(const SpeechPage()),
                            ),
                            _DrawerActionButton(
                              key: const Key('drawer_settings_action'),
                              icon: Icons.settings_outlined,
                              tooltip: l10n.drawerSettings,
                              onPressed: () =>
                                  _pushFromSidebar(const SettingsPage()),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: ChatPage(onOpenSidebar: _toggleSidebar),
        ),
      ),
    );
  }
}

class _DownloadCompletedListener extends StatefulWidget {
  const _DownloadCompletedListener({required this.child});

  final Widget child;

  @override
  State<_DownloadCompletedListener> createState() =>
      _DownloadCompletedListenerState();
}

class _DownloadCompletedListenerState
    extends State<_DownloadCompletedListener> {
  DownloadProvider? _downloads;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final downloads = context.read<DownloadProvider?>();
    if (identical(_downloads, downloads)) {
      return;
    }
    _unbind();
    _downloads = downloads;
    _downloads?.onDownloadCompleted = _showCompleted;
  }

  void _showCompleted(String fileName) {
    if (!mounted) {
      return;
    }
    AppMessage.show(
      context,
      context.l10n.downloadCompleted(fileName),
      tone: AppMessageTone.success,
    );
  }

  void _unbind() {
    if (_downloads?.onDownloadCompleted == _showCompleted) {
      _downloads?.onDownloadCompleted = null;
    }
  }

  @override
  void dispose() {
    _unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
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

class _DrawerActionButton extends StatelessWidget {
  const _DrawerActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.statusOnline,
    this.count = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool? statusOnline;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget content = Icon(icon, size: 22);
    if (statusOnline != null) {
      content = Badge(
        key: const Key('drawer_server_status_badge'),
        smallSize: 8,
        backgroundColor: statusOnline!
            ? const Color(0xFF10B981)
            : colors.outline,
        child: content,
      );
    } else if (count > 0) {
      content = Badge(label: Text('$count'), child: content);
    }
    return Semantics(
      value: statusOnline == null
          ? null
          : statusOnline!
          ? context.l10n.serverStatusRunning
          : context.l10n.serverStatusStopped,
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: colors.surfaceContainerHigh,
          foregroundColor: colors.onSurfaceVariant,
        ),
        icon: content,
      ),
    );
  }
}
