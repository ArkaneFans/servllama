import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/form_list_view.dart';
import 'package:servllama/shared/widgets/app_tab_bar.dart';
import 'package:servllama/shared/widgets/numeric_slider.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/app/model_library_page.dart';
import 'package:servllama/features/speech/pages/speech_job_page.dart';
import 'package:servllama/features/speech/pages/voice_profiles_page.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';
import 'package:servllama/features/speech/widgets/audio_input_panel.dart';
import 'package:servllama/features/speech/widgets/speech_job_widgets.dart';

class SpeechPage extends StatefulWidget {
  const SpeechPage({
    super.key,
    this.conversationId,
    this.draftAtEnqueue,
    this.forChat = false,
    this.initialText,
    this.initialKind,
  });
  final String? conversationId, draftAtEnqueue;
  final bool forChat;
  final String? initialText;
  final AssetKind? initialKind;
  @override
  State<SpeechPage> createState() => _SpeechPageState();
}

class _SpeechPageState extends State<SpeechPage> {
  final text = TextEditingController(),
      language = TextEditingController(),
      speaker = TextEditingController(text: '0');
  String? input, voiceId;
  double speed = 1;
  final _jobs = <AssetKind, String>{};
  final _submitting = <AssetKind>{};
  final _scrolls = {
    AssetKind.asr: ScrollController(),
    AssetKind.tts: ScrollController(),
  };

  bool busy(AssetKind kind, SpeechJobService service) =>
      _submitting.contains(kind) ||
      (_jobs[kind] != null && service.job(_jobs[kind]!)?.state.active == true);

  Widget result(AssetKind kind) => SpeechJobResult(
    key: ValueKey(_jobs[kind]),
    id: _jobs[kind]!,
    onRetry: (job) async {
      final service = context.read<SpeechJobService>();
      if (busy(kind, service)) return;
      setState(() => _submitting.add(kind));
      try {
        final next = await service.retry(job);
        if (mounted) setState(() => _jobs[kind] = next.id);
      } finally {
        if (mounted) setState(() => _submitting.remove(kind));
      }
    },
    onInsert: widget.forChat ? (job) => Navigator.pop(context, job) : null,
  );
  @override
  void initState() {
    super.initState();
    text.text = widget.initialText ?? '';
  }

  @override
  void dispose() {
    for (final scroll in _scrolls.values) {
      scroll.dispose();
    }
    text.dispose();
    language.dispose();
    speaker.dispose();
    super.dispose();
  }

  Future<void> enqueue(AssetKind kind) async {
    final s = context.read<SpeechJobService>();
    final asset = s.selected(kind);
    if (asset == null || busy(kind, s)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting.add(kind));
    try {
      final voice = s.voices
          .where((v) => v.id == voiceId && v.assetId == asset.id)
          .firstOrNull;
      final j = await s.enqueue(
        asset: asset,
        inputPath: kind == AssetKind.asr ? input : null,
        text: text.text,
        language: language.text,
        speaker: int.tryParse(speaker.text) ?? 0,
        speed: SpeechPackage.fromJson(asset.manifest).recipe.synthesisSpeed
            ? speed
            : 1,
        voice: voice,
        conversationId: widget.conversationId,
        draftAtEnqueue: widget.draftAtEnqueue,
      );
      if (!mounted) return;
      setState(() => _jobs[kind] = j.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final scroll = _scrolls[kind]!;
        if (mounted && scroll.hasClients) {
          scroll.animateTo(
            scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _submitting.remove(kind));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SpeechJobService?>(), l = context.l10n;
    if (s == null || !s.ready) {
      return AppScaffold(
        appBar: AppBar(title: Text(l.v2Speech)),
        body: Center(
          child: s?.loadError != null
              ? Text(s!.loadError!)
              : const CircularProgressIndicator(),
        ),
      );
    }
    final asr = s.selected(AssetKind.asr), tts = s.selected(AssetKind.tts);
    final recipe = tts == null
        ? null
        : SpeechPackage.fromJson(tts.manifest).recipe;
    return DefaultTabController(
      length: widget.forChat ? 1 : 3,
      initialIndex: widget.forChat
          ? 0
          : (widget.initialKind == AssetKind.tts ||
                    (widget.initialKind == null && widget.initialText != null)
                ? 1
                : 0),
      child: AppScaffold(
        appBar: AppBar(
          title: Text(widget.forChat ? l.v2TranscribeToChat : l.v2Speech),
          actions: [
            IconButton(
              tooltip: l.v2SpeechModels,
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ModelLibraryPage(initialTab: 1),
                ),
              ),
            ),
            IconButton(
              tooltip: l.v2Voices,
              icon: const Icon(Icons.record_voice_over_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const VoiceProfilesPage(),
                ),
              ),
            ),
          ],
          bottom: AppTabBar(
            tabs: [
              Tab(text: l.v2Asr),
              if (!widget.forChat) Tab(text: l.v2Tts),
              if (!widget.forChat) Tab(text: l.v2Tasks),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FormListView(
              controller: _scrolls[AssetKind.asr],
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  l.v2SpeechLocalHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SettingsSection.form(
                  title: l.v2Asr,
                  children: [
                    SpeechModelPicker(
                      kind: AssetKind.asr,
                      enabled: !busy(AssetKind.asr, s),
                    ),
                    TextField(
                      controller: language,
                      enabled: !busy(AssetKind.asr, s),
                      decoration: InputDecoration(labelText: l.v2LanguageHint),
                    ),
                  ],
                ),
                AudioInputPanel(
                  path: input,
                  enabled: !busy(AssetKind.asr, s),
                  onChanged: (path) => setState(() => input = path),
                ),
                FilledButton.icon(
                  key: const Key('speech_start_asr'),
                  icon: const Icon(Icons.transcribe),
                  label: Text(l.v2StartAsr),
                  onPressed:
                      asr == null ||
                          input == null ||
                          s.audio.recording ||
                          s.audio.recordingBusy ||
                          busy(AssetKind.asr, s)
                      ? null
                      : () =>
                            runUiAction(context, () => enqueue(AssetKind.asr)),
                ),
                if (asr == null) Text(l.v2InstallSpeechFirst),
                if (_jobs[AssetKind.asr] != null) result(AssetKind.asr),
              ],
            ),
            if (!widget.forChat)
              FormListView(
                controller: _scrolls[AssetKind.tts],
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  AbsorbPointer(
                    absorbing: busy(AssetKind.tts, s),
                    child: SettingsSection.form(
                      title: l.v2Tts,
                      children: [
                        const SpeechModelPicker(kind: AssetKind.tts),
                        TextField(
                          key: const Key('speech_synthesis_input'),
                          controller: text,
                          minLines: 4,
                          maxLines: 10,
                          maxLength: 4000,
                          decoration: InputDecoration(
                            labelText: l.v2SynthesisText,
                          ),
                        ),
                        if (widget.initialText != null) Text(l.v2ReadAloudHelp),
                        if (recipe == SpeechRecipe.sherpaVits)
                          TextField(
                            controller: speaker,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l.v2SpeakerId,
                            ),
                          ),
                        if (recipe?.canClone == true)
                          DropdownButtonFormField<String>(
                            key: ValueKey(tts!.id),
                            initialValue:
                                s.voices.any(
                                  (v) =>
                                      v.id == voiceId &&
                                      v.assetId == tts.id &&
                                      v.revision == tts.revision,
                                )
                                ? voiceId
                                : '',
                            isExpanded: true,
                            decoration: InputDecoration(labelText: l.v2Voice),
                            items: [
                              DropdownMenuItem(
                                value: '',
                                child: Text(l.v2PresetVoice),
                              ),
                              ...s.voices
                                  .where(
                                    (v) =>
                                        v.assetId == tts.id &&
                                        v.revision == tts.revision,
                                  )
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v.id,
                                      child: Text(v.name),
                                    ),
                                  ),
                            ],
                            onChanged: (v) => setState(() => voiceId = v),
                          ),
                        if (recipe?.synthesisSpeed == true) ...[
                          NumericSlider(
                            label: l.v2SynthesisSpeed,
                            value: speed,
                            min: 0.5,
                            max: 2,
                            divisions: 15,
                            onChanged: (v) => setState(() => speed = v),
                          ),
                        ],
                        if (recipe?.canClone == true)
                          Text(
                            l.v2CrispMarking,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),

                  FilledButton.icon(
                    key: const Key('speech_start_tts'),
                    icon: const Icon(Icons.graphic_eq),
                    label: Text(l.v2StartTts),
                    onPressed: tts == null || busy(AssetKind.tts, s)
                        ? null
                        : () => runUiAction(
                            context,
                            () => enqueue(AssetKind.tts),
                          ),
                  ),
                  if (tts == null) Text(l.v2InstallSpeechFirst),
                  if (_jobs[AssetKind.tts] != null) result(AssetKind.tts),
                ],
              ),
            if (!widget.forChat)
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  if (s.hasWaitingJobs) const SpeechWaitCard(),
                  if (s.jobs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l.v2NoSpeechJobs),
                    ),
                  ...s.jobs.map(
                    (job) => SpeechJobTile(
                      job: job,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => SpeechJobPage(id: job.id),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class SpeechModelPicker extends StatelessWidget {
  const SpeechModelPicker({super.key, required this.kind, this.enabled = true});
  final AssetKind kind;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SpeechJobService>();
    return DropdownButtonFormField<String>(
      key: ValueKey(s.selected(kind)?.id),
      initialValue: s.selected(kind)?.id,
      isExpanded: true,
      decoration: InputDecoration(labelText: context.l10n.v2SpeechModels),
      items: s.models.assets
          .where((a) => a.kind == kind && a.isReady)
          .map(
            (a) => DropdownMenuItem(
              value: a.id,
              child: Text(a.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: !enabled
          ? null
          : (id) {
              if (id != null) runUiAction(context, () => s.select(kind, id));
            },
    );
  }
}
