import 'package:servllama/shared/widgets/app_tab_bar.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:servllama/shared/widgets/ai_identity_icon.dart';
import 'dart:async';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/features/speech/widgets/speech_catalog_card.dart';
import 'package:servllama/features/downloads/pages/downloads_page.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/pages/hub_repo_page.dart';
import 'package:servllama/features/downloads/providers/model_discovery_provider.dart';
import 'package:servllama/features/downloads/services/model_catalog_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

/// Curated language/speech packages and online language repository search.
class ModelDiscoveryPage extends StatefulWidget {
  const ModelDiscoveryPage({super.key, this.initialPurpose = 'all'});
  final String initialPurpose;

  @override
  State<ModelDiscoveryPage> createState() => _ModelDiscoveryPageState();
}

class _ModelDiscoveryPageState extends State<ModelDiscoveryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ModelDiscoveryProvider>().load();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        context.read<ModelDiscoveryProvider>().search(value);
      }
    });
  }

  Future<void> _openRepo(
    String repoId,
    ModelHubSource source,
    InferenceEngine engine,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            HubRepoPage(repoId: repoId, source: source, engine: engine),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppScaffold(
      appBar: AppBar(
        title: Text(l10n.discoverTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: l10n.downloadsTitle,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const DownloadsPage()),
            ),
          ),
        ],
        bottom: AppTabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.discoverTabFeatured),
            Tab(text: l10n.discoveryOnlineLanguage),
          ],
        ),
      ),
      body: Consumer<ModelDiscoveryProvider>(
        builder: (context, discovery, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _FeaturedTab(
                discovery: discovery,
                onOpen: _openRepo,
                initialPurpose: widget.initialPurpose,
              ),
              _SearchTab(
                discovery: discovery,
                controller: _searchController,
                onQueryChanged: _onQueryChanged,
                onOpen: _openRepo,
              ),
            ],
          );
        },
      ),
    );
  }
}

typedef _OpenRepo =
    Future<void> Function(
      String repoId,
      ModelHubSource source,
      InferenceEngine engine,
    );

class _FeaturedTab extends StatefulWidget {
  const _FeaturedTab({
    required this.discovery,
    required this.onOpen,
    required this.initialPurpose,
  });
  final ModelDiscoveryProvider discovery;
  final _OpenRepo onOpen;
  final String initialPurpose;
  @override
  State<_FeaturedTab> createState() => _FeaturedTabState();
}

class _FeaturedTabState extends State<_FeaturedTab>
    with AutomaticKeepAliveClientMixin {
  late String purpose = widget.initialPurpose;
  String engine = 'all', status = 'all';
  bool clone = false, small = false;
  final query = TextEditingController();
  @override
  bool get wantKeepAlive => true;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l10n;
    final speech = context.watch<SpeechJobService?>();
    final m = speech?.ready == true ? speech!.models : null;
    final speechOnly = ['speech', 'asr', 'tts'].contains(purpose);
    final engines = <String, String>{
      'all': l.modelLibraryFilterAll,
      if (!speechOnly) 'llamaCpp': 'llama.cpp',
      if (!speechOnly) 'mnn': 'MNN',
      if (purpose != 'llm') 'sherpa_onnx': 'sherpa-onnx',
      if (purpose != 'llm') 'crispasr': 'CrispASR',
    };
    final q = query.text.trim().toLowerCase();
    final languages = widget.discovery.catalog
        .where(
          (e) =>
              !speechOnly &&
              (engine == 'all' || e.engine.name == engine) &&
              '${e.displayName} ${e.vendor} ${e.engine.name} ${RuntimeLabels.catalogSummary(l, e.summaryKey)}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    final packages = (m?.catalog ?? <SpeechPackage>[]).where((p) {
      if (purpose == 'llm' ||
          (purpose == 'asr' && p.recipe.kind != AssetKind.asr) ||
          (purpose == 'tts' && p.recipe.kind != AssetKind.tts)) {
        return false;
      }
      if (engine != 'all' && engine != p.recipe.engine) return false;
      if (!'${p.name} ${p.recipe.engine} ${p.recipe.name}'
          .toLowerCase()
          .contains(q.replaceAll('sherpa-onnx', 'sherpa_onnx'))) {
        return false;
      }
      if (clone && !p.recipe.canClone ||
          small && p.totalBytes > 200 * 1024 * 1024) {
        return false;
      }
      final a = m!.assetForPackage(p);
      final busy =
          m.isInstalling(p) || (a != null && m.progress.containsKey(a.id));
      return switch (status) {
        'ready' => a?.isReady == true,
        'active' => busy,
        'missing' => a == null && !busy,
        'incomplete' => a != null && !a.isReady && !busy,
        _ => true,
      };
    }).toList();
    Widget filter(
      String label,
      String value,
      Map<String, String> values,
      ValueChanged<String> change,
    ) => DropdownButton<String>(
      value: value,
      isExpanded: true,
      items: [
        for (final e in values.entries)
          DropdownMenuItem(
            value: e.key,
            child: Text('$label: ${e.value}', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) setState(() => change(v));
      },
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        TextField(
          controller: query,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: l.discoveryQuery,
          ),
        ),
        filter(
          l.discoveryPurpose,
          purpose,
          {
            'all': l.modelLibraryFilterAll,
            'llm': l.v2LlmModels,
            'speech': l.v2SpeechModels,
            'asr': l.v2Asr,
            'tts': l.v2Tts,
          },
          (v) {
            purpose = v;
            engine = 'all';
            status = 'all';
            clone = false;
            small = false;
          },
        ),
        filter(l.discoveryEngine, engine, engines, (v) => engine = v),
        if (speechOnly) ...[
          filter(l.discoveryState, status, {
            'all': l.modelLibraryFilterAll,
            'missing': l.discoveryNotInstalled,
            'active': l.discoveryDownloading,
            'ready': l.v2Ready,
            'incomplete': l.discoveryIncomplete,
          }, (v) => status = v),
          Wrap(
            spacing: 8,
            children: [
              if (purpose != 'asr')
                FilterChip(
                  label: Text(l.discoveryCloneOnly),
                  selected: clone,
                  onSelected: (v) => setState(() => clone = v),
                ),
              FilterChip(
                label: Text(l.discoverySmallOnly),
                selected: small,
                onSelected: (v) => setState(() => small = v),
              ),
            ],
          ),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => setState(() {
              purpose = 'all';
              engine = 'all';
              status = 'all';
              clone = false;
              small = false;
              query.clear();
            }),
            child: Text(l.discoveryReset),
          ),
        ),
        if (widget.discovery.isLoadingCatalog && !speechOnly)
          const LinearProgressIndicator(),
        for (final entry in languages)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CatalogCard(
              entry: entry,
              source: widget.discovery.activeSource,
              onOpen: widget.onOpen,
            ),
          ),
        if (purpose != 'llm' && m == null && speech != null)
          speech.loadError == null
              ? const LinearProgressIndicator()
              : Text(speech.loadError!),
        if (packages.isNotEmpty) Text(l.discoverySpeechHelp),
        for (final p in packages) SpeechCatalogCard(package: p),
        if (languages.isEmpty &&
            packages.isEmpty &&
            !widget.discovery.isLoadingCatalog)
          _CenteredHint(text: l.modelLibraryEmptySearchTitle),
      ],
    );
  }
}

class _CatalogCard extends StatelessWidget {
  const _CatalogCard({
    required this.entry,
    required this.source,
    required this.onOpen,
  });

  final CatalogEntry entry;
  final ModelHubSource source;
  final _OpenRepo onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    // Fall back to whichever hub carries this model when the preferred one
    // does not have it.
    final repoId = entry.repoIdFor(source) ?? entry.sources.values.firstOrNull;
    final effectiveSource = entry.repoIdFor(source) != null
        ? source
        : entry.sources.keys.first;

    return Material(
      color: colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: repoId == null
            ? null
            : () => onOpen(repoId, effectiveSource, entry.engine),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(96)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AiIdentityIcon(model: entry.displayName, local: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${entry.engine.displayName} · ${entry.vendor} · ${entry.parameterLabel}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                RuntimeLabels.catalogSummary(l10n, entry.summaryKey),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              if (entry.capabilities.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final capability in entry.capabilities)
                      _MiniTag(
                        label: RuntimeLabels.capability(l10n, capability),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchTab extends StatelessWidget {
  const _SearchTab({
    required this.discovery,
    required this.controller,
    required this.onQueryChanged,
    required this.onOpen,
  });

  final ModelDiscoveryProvider discovery;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final _OpenRepo onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
          child: TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: l10n.discoverSearchHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final source in ModelHubSource.values) ...[
                  _SourceChip(
                    label: source.displayName,
                    isSelected: discovery.activeSource == source,
                    onTap: () => discovery.setSource(source),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SourceChip(
                  label: l10n.discoverSortTrending,
                  isSelected: discovery.searchSort == HubSearchSort.trending,
                  onTap: () => discovery.setSearchSort(HubSearchSort.trending),
                ),
                const SizedBox(width: 8),
                _SourceChip(
                  label: l10n.discoverSortDownloads,
                  isSelected: discovery.searchSort == HubSearchSort.downloads,
                  onTap: () => discovery.setSearchSort(HubSearchSort.downloads),
                ),
                const SizedBox(width: 8),
                _SourceChip(
                  label: l10n.discoverSortLikes,
                  isSelected: discovery.searchSort == HubSearchSort.likes,
                  onTap: () => discovery.setSearchSort(HubSearchSort.likes),
                ),
                const SizedBox(width: 16),
                if (discovery.availableFormatFilters.contains(
                  HubFormatFilter.gguf,
                ))
                  _SourceChip(
                    label: 'GGUF',
                    isSelected: discovery.formatFilter == HubFormatFilter.gguf,
                    // Keep the only/default format selected; re-tapping is a no-op.
                    onTap: () =>
                        discovery.setFormatFilter(HubFormatFilter.gguf),
                  ),
                if (discovery.availableFormatFilters.contains(
                  HubFormatFilter.mnn,
                )) ...[
                  const SizedBox(width: 8),
                  _SourceChip(
                    label: 'MNN',
                    isSelected: discovery.formatFilter == HubFormatFilter.mnn,
                    onTap: () => discovery.setFormatFilter(HubFormatFilter.mnn),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(child: _buildResults(context, l10n)),
      ],
    );
  }

  Widget _buildResults(BuildContext context, dynamic l10n) {
    final results = discovery.displayedSearchResults;
    if (discovery.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (discovery.lastError != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: NoticeBanner(
          tone: StatusTone.danger,
          icon: Icons.wifi_off_rounded,
          message: RuntimeLabels.hubError(l10n, discovery.lastError!),
        ),
      );
    }
    if (results.isEmpty) {
      return _CenteredHint(text: l10n.discoverNoResults);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 320 &&
            discovery.hasMore &&
            !discovery.isLoadingMore &&
            discovery.loadMoreError == null) {
          unawaited(discovery.loadMore());
        }
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          for (final repo in results)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RepoResultCard(
                repo: repo,
                onOpen: () =>
                    onOpen(repo.repoId, repo.source, repo.likelyEngine),
              ),
            ),
          if (discovery.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (discovery.loadMoreError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                children: [
                  NoticeBanner(
                    tone: StatusTone.danger,
                    icon: Icons.wifi_off_rounded,
                    message: RuntimeLabels.hubError(
                      l10n,
                      discovery.loadMoreError!,
                    ),
                  ),
                  TextButton(
                    onPressed: discovery.loadMore,
                    child: Text(l10n.downloadRetry),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RepoResultCard extends StatelessWidget {
  const _RepoResultCard({required this.repo, required this.onOpen});

  final HubRepoSummary repo;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final updated = repo.lastModified == null
        ? l10n.discoverUpdatedUnknown
        : l10n.discoverUpdatedAt(
            MaterialLocalizations.of(
              context,
            ).formatCompactDate(repo.lastModified!.toLocal()),
          );

    return Material(
      color: colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(96)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              AiIdentityIcon(model: repo.repoId, local: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.repoId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${repo.source.displayName} · '
                      '${l10n.discoverDownloadsCount(repo.downloads)} · '
                      '$updated',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    EngineBadge(engine: repo.likelyEngine, compact: true),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.onSurface
              : (isLight
                    ? const Color(0xFFF1F3F7)
                    : colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: isSelected ? colorScheme.surface : colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFFF1F3F7)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
