import 'package:servllama/shared/widgets/form_list_view.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/features/speech/widgets/audio_input_panel.dart';
import 'package:servllama/features/speech/widgets/speech_job_widgets.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

class VoiceProfilesPage extends StatelessWidget {
  const VoiceProfilesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SpeechJobService>(), l = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l.v2Voices)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.v2CreateVoice),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const _VoiceEditor()),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Text(l.v2VoiceHelp, style: Theme.of(context).textTheme.bodySmall),
          ...s.voices.map(
            (v) => Card(
              child: ListTile(
                title: Text(v.name),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => _VoiceEditor(voice: v),
                  ),
                ),
                subtitle: Text(
                  v.referenceText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l.commonDelete,
                  onPressed: () => runUiAction(context, () => s.deleteVoice(v)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceEditor extends StatefulWidget {
  const _VoiceEditor({this.voice});
  final VoiceProfile? voice;
  @override
  State<_VoiceEditor> createState() => _VoiceEditorState();
}

class _VoiceEditorState extends State<_VoiceEditor> {
  final name = TextEditingController(),
      reference = TextEditingController(),
      sample = TextEditingController();
  String? assetId, input, jobId;
  final scroll = ScrollController();
  bool rights = false, saving = false;
  VoiceProfile? savedVoice;
  @override
  void initState() {
    super.initState();
    savedVoice = widget.voice;
    name.text = savedVoice?.name ?? '';
    reference.text = savedVoice?.referenceText ?? '';
    assetId = savedVoice?.assetId;
    rights = savedVoice != null;
  }

  @override
  void dispose() {
    scroll.dispose();
    name.dispose();
    reference.dispose();
    sample.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SpeechJobService>(), l = context.l10n;
    final previewing =
        saving || (jobId != null && s.job(jobId!)?.state.active == true);
    final candidates = s.models.assets
        .where(
          (a) =>
              a.kind == AssetKind.tts &&
              a.isReady &&
              SpeechPackage.fromJson(a.manifest).recipe.canClone,
        )
        .toList();
    final selected =
        candidates.where((a) => a.id == assetId).firstOrNull ??
        (savedVoice == null ? candidates.firstOrNull : null);
    return AppScaffold(
      appBar: AppBar(
        title: Text(savedVoice == null ? l.v2CreateVoice : l.v2Voices),
      ),
      body: FormListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          SettingsSection.form(
            title: l.v2Voices,
            subtitle: l.v2VoiceHelp,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selected?.id,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.v2SpeechModels),
                items: candidates
                    .map(
                      (a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: savedVoice == null
                    ? (id) => setState(() => assetId = id)
                    : null,
              ),
              if (selected == null)
                Text(
                  savedVoice == null
                      ? l.v2InstallCloningFirst
                      : l.v2VoiceModelMissing,
                ),
              TextField(
                controller: name,
                decoration: InputDecoration(labelText: l.v2VoiceName),
              ),
              if (savedVoice == null)
                AudioInputPanel(
                  path: input,
                  onChanged: (path) => setState(() => input = path),
                ),
              if (savedVoice != null)
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: Icon(
                        s.audio.playingPath == savedVoice!.path &&
                                s.audio.playing
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      label: Text(l.v2PreviewAudio),
                      onPressed: () => runUiAction(
                        context,
                        () => s.audio.play(savedVoice!.path),
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download),
                      label: Text(l.v2ExportWav),
                      onPressed: () => runUiAction(
                        context,
                        () => s.audio.exportAudio(
                          savedVoice!.path,
                          '${savedVoice!.id}-reference.wav',
                        ),
                      ),
                    ),
                  ],
                ),
              TextField(
                controller: reference,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(labelText: l.v2ReferenceText),
              ),
              if (savedVoice == null)
                CheckboxListTile(
                  value: rights,
                  title: Text(l.v2VoiceRights),
                  onChanged: (v) => setState(() => rights = v ?? false),
                ),
            ],
          ),
          SettingsSection.form(
            children: [
              TextField(
                key: const Key('voice_preview_input'),
                enabled: !previewing,
                controller: sample,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l.v2VoiceTestText),
              ),

              FilledButton(
                key: const Key('voice_save_preview'),
                onPressed:
                    previewing ||
                        selected == null ||
                        (input == null && savedVoice == null) ||
                        !rights ||
                        s.audio.recording ||
                        s.audio.recordingBusy
                    ? null
                    : () => runUiAction(context, () async {
                        if (sample.text.trim().isEmpty) {
                          throw FormatException(l.v2VoiceTestText);
                        }
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => saving = true);
                        try {
                          final voice = savedVoice == null
                              ? await s.createVoice(
                                  asset: selected,
                                  name: name.text,
                                  input: input!,
                                  referenceText: reference.text,
                                  rightsConfirmed: rights,
                                )
                              : await s.renameVoice(
                                  savedVoice!,
                                  name.text,
                                  reference.text,
                                );
                          if (mounted) setState(() => savedVoice = voice);
                          final job = await s.enqueue(
                            asset: selected,
                            text: sample.text,
                            voice: voice,
                          );
                          if (mounted) {
                            setState(() => jobId = job.id);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && scroll.hasClients) {
                                scroll.animateTo(
                                  scroll.position.maxScrollExtent,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                );
                              }
                            });
                          }
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      }),
                child: Text(l.v2SaveAndPreview),
              ),
              if (savedVoice != null)
                TextButton(
                  onPressed: previewing
                      ? null
                      : () => runUiAction(context, () async {
                          await s.renameVoice(
                            savedVoice!,
                            name.text,
                            reference.text,
                          );
                          if (context.mounted) Navigator.pop(context);
                        }),
                  child: Text(l.commonSave),
                ),
            ],
          ),
          if (jobId != null)
            SpeechJobResult(
              key: ValueKey(jobId),
              id: jobId!,
              onRetry: (previous) async {
                if (previewing) return;
                setState(() => saving = true);
                try {
                  final next = await s.retry(previous);
                  if (mounted) setState(() => jobId = next.id);
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
            ),
        ],
      ),
    );
  }
}
