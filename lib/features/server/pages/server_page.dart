import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/app_palette.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/library_model.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/providers/model_management_provider.dart';
import 'package:servllama/core/utils/format_utils.dart';
import 'package:servllama/features/downloads/pages/model_discovery_page.dart';
import 'package:servllama/features/server/pages/model_management_page.dart';
import 'package:servllama/features/server/pages/server_config_page.dart';
import 'package:servllama/features/server/pages/server_logs_page.dart';
import 'package:servllama/features/server/widgets/engine_selector.dart';
import 'package:servllama/features/server/widgets/runtime_hero_card.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

/// Runtime control center: pick an engine, pick a model, start or stop. The
/// two engines' native startup details are absorbed by [EngineRuntimeProvider];
/// this page reports whichever phase is current in the service status pill.
class ServerPage extends StatefulWidget {
  const ServerPage({super.key});

  @override
  State<ServerPage> createState() => _ServerPageState();
}

class _ServerPageState extends State<ServerPage> {
  Timer? _uptimeTicker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(context.read<EngineRuntimeProvider>().refresh());
      unawaited(context.read<ModelManagementProvider>().load());
      _syncUptimeTicker();
    });
  }

  /// The uptime line is the only thing on this page that changes without a
  /// state update, so it gets its own low-frequency tick — and only while
  /// there is an uptime to show, so an idle page schedules no timers at all.
  void _syncUptimeTicker() {
    final shouldTick = context.read<EngineRuntimeProvider>().isRunning;
    if (shouldTick == (_uptimeTicker != null)) {
      return;
    }
    if (shouldTick) {
      _uptimeTicker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      _uptimeTicker?.cancel();
      _uptimeTicker = null;
    }
  }

  @override
  void dispose() {
    _uptimeTicker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final runtime = context.watch<EngineRuntimeProvider>();
    final library = context.watch<ModelManagementProvider>();
    final state = runtime.state;
    _syncUptimeTicker();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            EngineSelector(
              selected: state.engine,
              enabled: runtime.canSwitchEngine,
              onChanged: runtime.switchEngine,
            ),
            const SizedBox(height: 18),
            RuntimeHeroCard(
              state: state,
              displayUrl: runtime.displayUrl,
              selectedModelId: runtime.selectedModelId,
              selectedModelName: _modelNameFor(
                library,
                state.engine,
                runtime.selectedModelId,
              ),
              canStart: runtime.canStart,
              onSelectModel: () => _openModelPicker(context, runtime, library),
              onToggle: runtime.toggle,
              onCopyUrl: () => _copyBaseUrl(context, runtime.displayUrl),
            ),
            if (runtime.exposesLanWithoutApiKey) ...[
              const SizedBox(height: 12),
              NoticeBanner(
                key: const Key('server_open_access_warning'),
                tone: StatusTone.warning,
                icon: Icons.security_rounded,
                message: l10n.serverOpenAccessWarning,
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 16),
              NoticeBanner(
                tone: StatusTone.danger,
                icon: Icons.error_outline_rounded,
                message: RuntimeLabels.runtimeError(
                  l10n,
                  state.error!,
                  runtime.port,
                ),
              ),
            ],
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
                  trailing: '${library.libraryModels.length}',
                  onTap: () => _push(context, const ModelManagementPage()),
                ),
                _MenuItemData(
                  icon: Icons.travel_explore_rounded,
                  title: l10n.discoverTitle,
                  onTap: () => _push(context, const ModelDiscoveryPage()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _modelNameFor(
    ModelManagementProvider library,
    InferenceEngine engine,
    String? runtimeId,
  ) {
    if (runtimeId == null) {
      return null;
    }
    for (final model in library.libraryModelsFor(engine)) {
      if (model.runtimeId == runtimeId) {
        return model.name;
      }
    }
    return runtimeId;
  }

  Future<void> _openModelPicker(
    BuildContext context,
    EngineRuntimeProvider runtime,
    ModelManagementProvider library,
  ) async {
    final engine = runtime.activeEngine;
    final selection = await showModalBottomSheet<_ModelPick>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ModelPickerSheet(
        engine: engine,
        models: library.libraryModelsFor(engine),
        selectedRuntimeId: runtime.selectedModelId,
      ),
    );
    if (selection == null) {
      return;
    }
    // While idle this only records the choice; the start button brings the
    // runtime up. While running it triggers a same-engine swap.
    if (runtime.isRunning) {
      await runtime.activateModel(selection.runtimeId);
    } else if (!runtime.isRunning) {
      await runtime.selectModel(selection.runtimeId);
    }
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

  static Future<void> _push(BuildContext context, Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _ModelPick {
  const _ModelPick(this.runtimeId);

  final String runtimeId;
}

class _ModelPickerSheet extends StatelessWidget {
  const _ModelPickerSheet({
    required this.engine,
    required this.models,
    required this.selectedRuntimeId,
  });

  final InferenceEngine engine;
  final List<LibraryModel> models;
  final String? selectedRuntimeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.serverSelectModelTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                EngineBadge(engine: engine),
              ],
            ),
            const SizedBox(height: 14),
            if (models.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  l10n.serverNoModelsForEngine(engine.displayName),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: models.length,
                  itemBuilder: (_, index) {
                    final model = models[index];
                    final isSelected = model.runtimeId == selectedRuntimeId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ModelFormatBadge(engine: model.engine, size: 40),
                      title: Text(
                        model.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(FormatUtils.bytes(model.sizeBytes)),
                      selected: isSelected,
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: theme.palette.okMark,
                            )
                          : null,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(_ModelPick(model.runtimeId)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
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
                if (widget.item.trailing != null) ...[
                  Text(
                    widget.item.trailing!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
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
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? trailing;
}
