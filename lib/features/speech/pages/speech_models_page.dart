import 'package:servllama/shared/widgets/ai_identity_icon.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:servllama/features/downloads/widgets/download_wifi_only_gate.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/downloads/pages/model_discovery_page.dart';
import 'package:servllama/features/speech/pages/speech_page.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

class SpeechModelsPage extends StatelessWidget {
  const SpeechModelsPage({
    super.key,
    this.embedded = false,
    this.downloadsOnly = false,
  });
  final bool embedded;
  final bool downloadsOnly;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SpeechJobService?>(), l = context.l10n;
    if (s == null || !s.ready) {
      return Center(
        child: s?.loadError == null
            ? const CircularProgressIndicator()
            : Text(s!.loadError!),
      );
    }
    final m = s.models;
    final visibleAssets = m.assets
        .where(
          (a) =>
              !downloadsOnly ||
              (a.manifest['files'] as List? ?? []).any((f) => f['url'] != null),
        )
        .toList();
    return AppScaffold(
      appBar: embedded ? null : AppBar(title: Text(l.v2SpeechModels)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(l.discoverySpeechLibraryHelp),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.explore_outlined),
              label: Text(l.discoverTitle),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const ModelDiscoveryPage(initialPurpose: 'speech'),
                ),
              ),
            ),
          ),
          if (visibleAssets.isEmpty) Text(l.downloadsEmpty),
          ...visibleAssets.map(
            (a) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AiIdentityIcon(model: a.name, local: true),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            a.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      m.progress.containsKey(a.id)
                          ? l.discoveryDownloading
                          : a.isReady
                          ? l.v2Ready
                          : l.v2ModelIncomplete,
                    ),
                    Text(a.engine),
                    if (m.progress.containsKey(a.id))
                      LinearProgressIndicator(value: m.progress[a.id]),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (a.isReady)
                          TextButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: Text(l.v2Speech),
                            onPressed: () => runUiAction(context, () async {
                              await s.select(a.kind, a.id);
                              if (context.mounted) {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        SpeechPage(initialKind: a.kind),
                                  ),
                                );
                              }
                            }),
                          ),
                        if (!a.isReady &&
                            a.state != 'importing' &&
                            !m.progress.containsKey(a.id) &&
                            (a.manifest['files'] as List? ?? []).every(
                              (f) => f['url'] != null,
                            ))
                          TextButton.icon(
                            icon: const Icon(Icons.download),
                            label: Text(l.v2ResumeDownload),
                            onPressed: () => runUiAction(context, () async {
                              if (await confirmDownloadOnMeteredNetwork(
                                context,
                              )) {
                                await m.resume(a);
                              }
                            }),
                          ),
                        if (m.progress.containsKey(a.id))
                          TextButton(
                            onPressed: () => m.pause(a.id),
                            child: Text(l.v2PauseDownload),
                          ),
                        if (a.state != 'importing' &&
                            !m.progress.containsKey(a.id))
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: Text(l.commonDelete),
                            onPressed: () => runUiAction(context, () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: Text(l.commonDelete),
                                  content: Text(l.v2DeleteSpeechModelHelp),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: Text(l.commonCancel),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: Text(l.commonDelete),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) await m.delete(a);
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
