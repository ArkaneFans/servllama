import 'package:servllama/shared/widgets/ai_identity_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/models/engine_runtime_state.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/pages/connections_page.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';

Future<ChatTarget?> showChatTargetPicker(
  BuildContext context, {
  ChatTarget? initialTarget,
  Future<void> Function(ChatTarget)? onSelected,
}) => showModalBottomSheet<ChatTarget>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: .88,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ChatTargetPicker(
        initialTarget: initialTarget,
        onSelected: onSelected,
      ),
    ),
  ),
);

/// One catalog view for chat and assistant defaults. The caller owns writes and
/// startup; a settings-only picker never loads a local model.
class ChatTargetPicker extends StatefulWidget {
  const ChatTargetPicker({super.key, this.initialTarget, this.onSelected});
  final ChatTarget? initialTarget;
  final Future<void> Function(ChatTarget)? onSelected;
  @override
  State<ChatTargetPicker> createState() => _ChatTargetPickerState();
}

class _ChatTargetPickerState extends State<ChatTargetPicker> {
  final search = TextEditingController();
  final scroll = ScrollController();
  bool refreshing = false, selecting = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    search.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _reportError(Object cause) {
    AppLogger.instance.event(
      'ui.action.failed',
      level: LogLevel.error,
      fields: AppLogger.errorFields(cause),
    );
    if (!mounted) return;
    setState(() => error = LogRedactor.redact(cause.toString()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scroll.hasClients) scroll.jumpTo(0);
    });
  }

  Future<void> _refresh() async {
    setState(() {
      refreshing = true;
      error = null;
    });
    try {
      await context.read<AssistantProvider>().refreshAssets();
    } catch (e) {
      _reportError(e);
    } finally {
      if (mounted) setState(() => refreshing = false);
    }
  }

  Future<void> _choose(ChatTarget target) async {
    if (selecting || refreshing) return;
    setState(() {
      selecting = true;
      error = null;
    });
    try {
      await widget.onSelected?.call(target);
      if (mounted) Navigator.pop(context, target);
    } catch (e) {
      _reportError(e);
    } finally {
      if (mounted) setState(() => selecting = false);
    }
  }

  Future<void> _manage() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const ConnectionsPage()),
    );
    if (mounted) await _refresh();
  }

  bool _selected(ChatTarget? current, ChatTarget target) =>
      current?.assetId == target.assetId &&
      current?.connectionId == target.connectionId &&
      current?.modelId == target.modelId;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AssistantProvider>();
    final runtime = context.watch<EngineRuntimeProvider?>();
    final chat = context.watch<ChatProvider?>();
    final l = context.l10n;
    final query = search.text.trim().toLowerCase();
    final current = widget.onSelected == null
        ? widget.initialTarget
        : chat?.currentTarget ?? widget.initialTarget;
    final disabled =
        selecting ||
        refreshing ||
        (widget.onSelected != null && chat?.canManageSessions == false);
    final slivers = <Widget>[
      if (error != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                '${l.v2OperationFailed}\n$error',
                key: const Key('chat_target_error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ),
    ];
    for (final engine in InferenceEngine.values) {
      final name = l.v2LocalProvider(engine.displayName);
      final all = p.assets
          .where(
            (a) => a.kind == AssetKind.llm && a.engine == engine.storageValue,
          )
          .toList();
      final matchesProvider = name.toLowerCase().contains(query);
      final assets = all
          .where(
            (a) =>
                matchesProvider ||
                a.name.toLowerCase().contains(query) ||
                a.runtimeId.toLowerCase().contains(query),
          )
          .toList();
      if (!matchesProvider && assets.isEmpty) continue;
      final activeEngine = runtime?.activeEngine == engine;
      final status = activeEngine && runtime!.isPublished
          ? l.v2ServicePublished
          : RuntimeLabels.status(
              l,
              activeEngine ? runtime!.state.status : EngineRuntimeStatus.idle,
            );
      slivers.add(
        SliverToBoxAdapter(
          child: _ProviderHeading(
            name: name,
            status: status,
            icon: activeEngine && runtime!.isBusy
                ? Icons.timelapse_rounded
                : activeEngine && runtime!.isRunning
                ? Icons.play_circle_outline_rounded
                : Icons.stop_circle_outlined,
            active: activeEngine && (runtime!.isRunning || runtime.isBusy),
          ),
        ),
      );
      if (assets.isEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(l.v2NoLocalChatModels),
            ),
          ),
        );
      }
      slivers.add(
        SliverList.builder(
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            final loaded =
                activeEngine &&
                runtime!.isRunning &&
                runtime.activeModelId == asset.runtimeId;
            final loading =
                activeEngine &&
                runtime!.isBusy &&
                runtime.selectedModelId == asset.runtimeId;
            final publishedConflict =
                widget.onSelected != null &&
                runtime?.isPublished == true &&
                !loaded;
            final busy = widget.onSelected != null && runtime?.isBusy == true;
            final target = ChatTarget.local(asset.id);
            final subtitle = !asset.isReady
                ? l.v2MissingTarget
                : publishedConflict
                ? l.v2PublishedModelLocked
                : loading
                ? l.serverStatusPreparing
                : loaded
                ? l.v2LocalModelLoaded
                : l.v2LocalModelUnloaded;
            return ListTile(
              key: ValueKey('chat_target_local_${asset.id}'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
              title: Tooltip(
                message: '${asset.name} · $subtitle',
                child: Text(
                  asset.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              selected: _selected(current, target),
              leading: AiIdentityIcon(
                model: asset.name,
                local: true,
                size: 24,
                framed: false,
              ),
              enabled:
                  !disabled && asset.isReady && !publishedConflict && !busy,
              onTap: () => _choose(target),
            );
          },
        ),
      );
    }
    for (final c in p.connections.where((c) => c.enabled)) {
      final matchesProvider = c.name.toLowerCase().contains(query);
      final models = c.models
          .where((id) => matchesProvider || id.toLowerCase().contains(query))
          .toList();
      if (!matchesProvider && models.isEmpty) continue;
      slivers.add(SliverToBoxAdapter(child: _ProviderHeading(name: c.name)));
      if (models.isEmpty) {
        slivers.add(
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 16, 12),
              child: Text(l.v2ProviderModelsEmpty),
            ),
          ),
        );
      }
      slivers.add(
        SliverList.builder(
          itemCount: models.length,
          itemBuilder: (context, index) {
            final id = models[index];
            final target = ChatTarget.remote(c.id, id);
            return ListTile(
              key: ValueKey('chat_target_remote_${c.id}_$id'),
              leading: AiIdentityIcon(
                model: id,
                providerId: c.id,
                providerName: c.name,
                baseUrl: c.baseUrl,
                size: 24,
                framed: false,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
              title: Text(id, maxLines: 1, overflow: TextOverflow.ellipsis),
              enabled: !disabled && c.enabled,
              selected: _selected(current, target),
              onTap: () => _choose(target),
            );
          },
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.v2ConversationModel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const Key('chat_target_manage'),
                tooltip: l.v2Connections,
                icon: const Icon(Icons.settings_outlined),
                onPressed: disabled ? null : _manage,
              ),
              IconButton(
                key: const Key('chat_target_close'),
                tooltip: l.commonCancel,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TextField(
            key: const Key('chat_target_search'),
            controller: search,
            decoration: InputDecoration(
              hintText: l.v2ProviderModelSearch,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l.appLogsClearSearch,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(search.clear),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        if (selecting || refreshing) const LinearProgressIndicator(),
        Expanded(
          child: slivers.isEmpty
              ? Center(child: Text(l.modelLibraryEmptySearchTitle))
              : CustomScrollView(
                  controller: scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      sliver: SliverMainAxisGroup(slivers: slivers),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ProviderHeading extends StatelessWidget {
  const _ProviderHeading({
    required this.name,
    this.status,
    this.icon,
    this.active = false,
  });
  final String name;
  final String? status;
  final IconData? icon;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 8),
      child: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (icon != null) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: status!,
              child: Icon(
                icon,
                size: 16,
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
