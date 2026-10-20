import 'package:servllama/shared/widgets/ai_identity_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/features/speech/pages/speech_page.dart';
import 'package:servllama/features/downloads/widgets/download_wifi_only_gate.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

class SpeechCatalogCard extends StatelessWidget {
  const SpeechCatalogCard({super.key, required this.package});
  final SpeechPackage package;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SpeechJobService>();
    final m = s.models;
    final l = context.l10n;
    final a = m.assetForPackage(package);
    final active = a != null && m.progress.containsKey(a.id);
    final busy = m.isInstalling(package) || active;
    final ready = a?.isReady == true;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AiIdentityIcon(model: package.name, local: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    package.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${package.recipe.engine == 'sherpa_onnx' ? 'sherpa-onnx' : 'CrispASR'} · ${package.recipe.kind == AssetKind.asr ? l.v2Asr : l.v2Tts}',
            ),
            Text(l.v2DownloadSize((package.totalBytes / 1024 / 1024).ceil())),
            if (package.recipe.canClone)
              Chip(label: Text(l.discoveryCloneOnly)),
            Text(
              ready
                  ? l.v2Ready
                  : busy
                  ? l.discoveryDownloading
                  : a == null
                  ? l.discoveryNotInstalled
                  : l.v2ModelIncomplete,
            ),
            if (busy)
              LinearProgressIndicator(
                value: a == null ? null : m.progress[a.id],
              ),
            const SizedBox(height: 8),
            Text(
              l.v2ModelLicenseHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => runUiAction(context, () async {
                    await launchUrl(Uri.parse(package.sourceUrl));
                  }),
                  child: Text(l.v2ModelCard),
                ),
                if (active)
                  TextButton(
                    onPressed: () => m.pause(a.id),
                    child: Text(l.v2PauseDownload),
                  )
                else if (ready)
                  FilledButton.tonal(
                    onPressed: () => runUiAction(context, () async {
                      await s.select(a!.kind, a.id);
                      if (context.mounted) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SpeechPage(initialKind: a.kind),
                          ),
                        );
                      }
                    }),
                    child: Text(
                      package.recipe.kind == AssetKind.asr ? l.v2Asr : l.v2Tts,
                    ),
                  )
                else
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.download),
                    label: Text(
                      a == null ? l.v2DownloadModel : l.v2ResumeDownload,
                    ),
                    onPressed: busy
                        ? null
                        : () => runUiAction(context, () async {
                            if (await confirmDownloadOnMeteredNetwork(
                              context,
                            )) {
                              await m.install(package);
                            }
                          }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
