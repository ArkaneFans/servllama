import 'package:servllama/shared/widgets/app_tab_bar.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:servllama/features/downloads/pages/model_discovery_page.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/downloads/pages/downloads_page.dart';
import 'package:servllama/features/downloads/providers/download_provider.dart';
import 'package:servllama/features/server/pages/model_management_page.dart';
import 'package:servllama/features/speech/pages/speech_models_page.dart';
import 'package:servllama/l10n/l10n.dart';

/// Shared entry point; model ownership remains with the existing repositories.
class ModelLibraryPage extends StatelessWidget {
  const ModelLibraryPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final downloads = context.watch<DownloadProvider>();
    final speech = context.watch<SpeechJobService?>();
    final activeCount =
        downloads.activeTaskCount +
        (speech?.ready == true ? speech!.models.progress.length : 0);
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Builder(
        builder: (context) {
          final tabs = DefaultTabController.of(context);
          return ListenableBuilder(
            listenable: tabs,
            builder: (context, _) => AppScaffold(
              appBar: AppBar(
                title: Text(l.modelLibraryTitle),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.explore_outlined),
                    tooltip: l.discoverTitle,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ModelDiscoveryPage(
                          initialPurpose: tabs.index == 1 ? 'speech' : 'all',
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('model_library_downloads_button'),
                    tooltip: l.downloadsTitle,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DownloadsPage(initialTab: tabs.index),
                      ),
                    ),
                    icon: Badge(
                      isLabelVisible: activeCount > 0,
                      label: Text('$activeCount'),
                      child: const Icon(Icons.download_rounded),
                    ),
                  ),
                ],
                bottom: AppTabBar(
                  tabs: [
                    Tab(
                      key: const Key('model_library_language_tab'),
                      text: l.v2LlmModels,
                    ),
                    Tab(
                      key: const Key('model_library_speech_tab'),
                      text: l.v2SpeechModels,
                    ),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  ExcludeFocus(
                    excluding: tabs.index != 0,
                    child: const ModelManagementPage(embedded: true),
                  ),
                  const SpeechModelsPage(embedded: true),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
