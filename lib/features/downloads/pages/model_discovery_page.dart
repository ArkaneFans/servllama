import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/utils/format_utils.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/pages/hub_repo_page.dart';
import 'package:servllama/features/downloads/providers/model_discovery_provider.dart';
import 'package:servllama/features/downloads/services/device_capability_service.dart';
import 'package:servllama/features/downloads/services/model_catalog_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/l10n/runtime_labels.dart';
import 'package:servllama/shared/widgets/engine_badge.dart';

/// Two ways to find a model (design decision D3): a curated list that has
/// been run on real devices, and raw hub search for everything else. The
/// device memory banner sits above both, because "will it run" is the
/// question that decides everything below it.
class ModelDiscoveryPage extends StatefulWidget {
  const ModelDiscoveryPage({super.key});

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

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.discoverTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.discoverTabFeatured),
            Tab(text: l10n.discoverTabSearch),
          ],
        ),
      ),
      body: Consumer<ModelDiscoveryProvider>(
        builder: (context, discovery, _) {
          return Column(
            children: [
              _MemoryBanner(memory: discovery.memory),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _FeaturedTab(discovery: discovery, onOpen: _openRepo),
                    _SearchTab(
                      discovery: discovery,
                      controller: _searchController,
                      onQueryChanged: _onQueryChanged,
                      onOpen: _openRepo,
                      onBackToFeatured: () => _tabController.animateTo(0),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MemoryBanner extends StatelessWidget {
  const _MemoryBanner({required this.memory});

  final DeviceMemoryInfo memory;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: NoticeBanner(
        tone: memory.isKnown ? StatusTone.idle : StatusTone.warning,
        icon: Icons.memory_rounded,
        message: memory.isKnown
            ? l10n.discoverDeviceMemory(
                FormatUtils.bytes(memory.availableBytes),
                FormatUtils.bytes(memory.totalBytes),
              )
            : l10n.discoverDeviceMemoryUnknown,
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

class _FeaturedTab extends StatelessWidget {
  const _FeaturedTab({required this.discovery, required this.onOpen});

  final ModelDiscoveryProvider discovery;
  final _OpenRepo onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    if (discovery.isLoadingCatalog) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            l10n.discoverFeaturedNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final entry in discovery.catalog)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _CatalogCard(
              entry: entry,
              source: discovery.activeSource,
              onOpen: onOpen,
            ),
          ),
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
    final isLight = theme.brightness == Brightness.light;
    final l10n = context.l10n;
    // Fall back to whichever hub carries this model when the preferred one
    // does not have it.
    final repoId = entry.repoIdFor(source) ?? entry.sources.values.firstOrNull;
    final effectiveSource = entry.repoIdFor(source) != null
        ? source
        : entry.sources.keys.first;

    return Material(
      color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: repoId == null
            ? null
            : () => onOpen(repoId, effectiveSource, entry.engine),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(96)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ModelFormatBadge(engine: entry.engine, size: 40),
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
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${entry.vendor} · ${entry.parameterLabel}',
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
    required this.onBackToFeatured,
  });

  final ModelDiscoveryProvider discovery;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final _OpenRepo onOpen;
  final VoidCallback onBackToFeatured;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
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
                _SourceChip(
                  label: l10n.discoverSourceAll,
                  isSelected: discovery.searchAllSources,
                  onTap: discovery.setSearchAllSources,
                ),
                const SizedBox(width: 8),
                for (final source in ModelHubSource.values) ...[
                  _SourceChip(
                    label: source.displayName,
                    isSelected:
                        !discovery.searchAllSources &&
                        discovery.activeSource == source,
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
                  label: l10n.discoverSortDownloads,
                  isSelected: discovery.searchSort == HubSearchSort.downloads,
                  onTap: () => discovery.setSearchSort(HubSearchSort.downloads),
                ),
                const SizedBox(width: 8),
                _SourceChip(
                  label: l10n.discoverSortUpdated,
                  isSelected: discovery.searchSort == HubSearchSort.updated,
                  onTap: () => discovery.setSearchSort(HubSearchSort.updated),
                ),
                const SizedBox(width: 16),
                _SourceChip(
                  label: l10n.discoverFormatAll,
                  isSelected: discovery.formatFilter == HubFormatFilter.all,
                  onTap: () => discovery.setFormatFilter(HubFormatFilter.all),
                ),
                const SizedBox(width: 8),
                _SourceChip(
                  label: 'GGUF',
                  isSelected: discovery.formatFilter == HubFormatFilter.gguf,
                  onTap: () => discovery.setFormatFilter(HubFormatFilter.gguf),
                ),
                const SizedBox(width: 8),
                _SourceChip(
                  label: 'MNN',
                  isSelected: discovery.formatFilter == HubFormatFilter.mnn,
                  onTap: () => discovery.setFormatFilter(HubFormatFilter.mnn),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: _buildResults(context, l10n, theme)),
      ],
    );
  }

  Widget _buildResults(BuildContext context, dynamic l10n, ThemeData theme) {
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
    if (discovery.query.trim().isEmpty) {
      return _CenteredHint(text: l10n.discoverSearchPrompt);
    }
    if (results.isEmpty) {
      return _CenteredHint(text: l10n.discoverNoResults);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            l10n.discoverResultCount(results.length),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NoticeBanner(
                tone: StatusTone.warning,
                message: l10n.discoverSearchDisclaimer,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onBackToFeatured,
                  icon: const Icon(Icons.verified_outlined),
                  label: Text(l10n.discoverBackToFeatured),
                ),
              ),
            ],
          ),
        ),
        for (final repo in results)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RepoResultCard(
              repo: repo,
              onOpen: () => onOpen(repo.repoId, repo.source, repo.likelyEngine),
            ),
          ),
      ],
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
    final isLight = theme.brightness == Brightness.light;
    final l10n = context.l10n;
    final updated = repo.lastModified == null
        ? l10n.discoverUpdatedUnknown
        : l10n.discoverUpdatedAt(
            MaterialLocalizations.of(
              context,
            ).formatCompactDate(repo.lastModified!.toLocal()),
          );
    final fileCount = repo.fileCount == null
        ? l10n.discoverFileCountUnknown
        : l10n.discoverFileCount(repo.fileCount!);

    return Material(
      color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(96)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repo.repoId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
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
                    Row(
                      children: [
                        EngineBadge(engine: repo.likelyEngine, compact: true),
                        const SizedBox(width: 8),
                        _MiniTag(label: fileCount),
                      ],
                    ),
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
