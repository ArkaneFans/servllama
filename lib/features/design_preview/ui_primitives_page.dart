import 'dart:async';
import 'package:servllama/shared/widgets/app_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:servllama/shared/widgets/app_message.dart';
import 'package:servllama/shared/widgets/numeric_slider.dart';
import 'package:servllama/features/design_preview/preview_theme.dart';
import 'package:servllama/l10n/l10n.dart';

/// All gallery interactions are local state: no application providers or I/O.
class UiPrimitivesPage extends StatefulWidget {
  const UiPrimitivesPage({super.key});
  @override
  State<UiPrimitivesPage> createState() => _UiPrimitivesPageState();
}

class _UiPrimitivesPageState extends State<UiPrimitivesPage> {
  final _feedbackHost = GlobalKey<AppMessageHostState>();
  Brightness? _brightness;
  PreviewPalette _palette = PreviewPalette.violet;
  final _name = TextEditingController();
  final _message = TextEditingController();
  final _sceneScroll = ScrollController();
  bool _enabled = true;
  bool _invalid = false;
  bool _vision = false;
  double _temperature = 0.6;
  double _progress = 0;
  Timer? _timer;
  int _model = 0;
  String? _sent;

  @override
  void dispose() {
    _name.dispose();
    _message.dispose();
    _sceneScroll.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _feedback(BuildContext context) {
    AppMessageHost.of(context).show(context.l10n.uiLabFeedback);
  }

  void _transfer() {
    _timer?.cancel();
    setState(() => _progress = 0);
    _timer = Timer.periodic(const Duration(milliseconds: 240), (timer) {
      setState(() => _progress = (_progress + 0.1).clamp(0, 1));
      if (_progress >= 1) timer.cancel();
    });
  }

  Future<void> _models(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.uiLabChooseModel,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.uiLabLocalOnly,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              for (var index = 0; index < 2; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    color: index == _model
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    child: ListTile(
                      key: ValueKey('ui_lab_model_$index'),
                      leading: Icon(
                        index == 0
                            ? Icons.memory_outlined
                            : Icons.auto_awesome_outlined,
                      ),
                      title: Text(index == 0 ? 'Qwen3 · 4B' : 'Gemini · Flash'),
                      subtitle: Text(
                        index == 0
                            ? context.l10n.uiLabOnDevice
                            : context.l10n.uiLabCloud,
                      ),
                      trailing: index == _model
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.pop(context, index),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (mounted && selected != null) setState(() => _model = selected);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _brightness ?? Theme.of(context).brightness;
    return Theme(
      data: PreviewTheme.build(brightness, palette: _palette),
      child: DefaultTabController(
        length: 3,
        child: Builder(
          builder: (context) {
            final l = context.l10n;
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  l.uiLabTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  PopupMenuButton<PreviewPalette>(
                    key: const Key('ui_lab_palette'),
                    tooltip: l.uiLabThemeColor,
                    icon: Icon(
                      Icons.palette_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    initialValue: _palette,
                    onSelected: (value) => setState(() => _palette = value),
                    itemBuilder: (context) => [
                      for (final palette in PreviewPalette.values)
                        CheckedPopupMenuItem<PreviewPalette>(
                          key: ValueKey('ui_lab_palette_${palette.name}'),
                          value: palette,
                          checked: palette == _palette,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 16,
                                color: PreviewTheme.build(
                                  brightness,
                                  palette: palette,
                                ).colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  palette == PreviewPalette.tea
                                      ? l.uiLabTea
                                      : l.uiLabViolet,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    key: const Key('ui_lab_brightness'),
                    tooltip: brightness == Brightness.light
                        ? l.uiLabDark
                        : l.uiLabLight,
                    onPressed: () => setState(
                      () => _brightness = brightness == Brightness.light
                          ? Brightness.dark
                          : Brightness.light,
                    ),
                    icon: Icon(
                      brightness == Brightness.light
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                bottom: AppTabBar(
                  onTap: (_) => _feedbackHost.currentState?.hide(),
                  tabs: [
                    Tab(key: const Key('ui_lab_visuals'), text: l.uiLabVisuals),
                    Tab(
                      key: const Key('ui_lab_controls'),
                      text: l.uiLabControls,
                    ),
                    Tab(key: const Key('ui_lab_scenes'), text: l.uiLabScenes),
                  ],
                ),
              ),
              body: SafeArea(
                top: false,
                child: AppMessageHost(
                  key: _feedbackHost,
                  child: Builder(
                    builder: (context) => TabBarView(
                      children: [
                        _visuals(context),
                        _controls(context),
                        _scenes(context),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _visuals(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context);
    final c = t.colorScheme;
    return ListView(
      key: const PageStorageKey('ui_lab_visual_list'),
      padding: const EdgeInsets.all(PreviewTheme.pageInset),
      children: [
        _Surface(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Badge(l.uiLabPreview, c.primary, c.primaryContainer),
                const SizedBox(height: 16),
                Text(l.uiLabHeadline, style: t.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  _palette == PreviewPalette.tea
                      ? l.uiLabTeaIntro
                      : l.uiLabIntro,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Badge(
                      l.uiLabQuiet,
                      c.onSurfaceVariant,
                      c.surfaceContainerLow,
                    ),
                    _Badge(
                      l.uiLabSoft,
                      c.onSurfaceVariant,
                      c.surfaceContainerLow,
                    ),
                    _Badge(
                      'Material 3',
                      c.onSurfaceVariant,
                      c.surfaceContainerLow,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _Section('01', l.uiLabPalette, l.uiLabPaletteHint),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 12) / 2;
            final colors = [
              (l.uiLabCanvas, c.surface),
              (l.uiLabSurface, c.surfaceContainerLowest),
              (l.uiLabPrimary, c.primary),
              (l.uiLabSelected, c.primaryContainer),
            ];
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in colors)
                  SizedBox(
                    width: width,
                    child: _Surface(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: item.$2,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: c.outlineVariant),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(item.$1, style: t.textTheme.bodyMedium),
                            Text(
                              '#${item.$2.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                              style: t.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        _Section('02', l.uiLabTypography, l.uiLabTypographyHint),
        _Surface(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.uiLabTypeTitle, style: t.textTheme.headlineSmall),
                const SizedBox(height: 16),
                Text(l.uiLabTypeSection, style: t.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(l.uiLabTypeBody, style: t.textTheme.bodyLarge),
                const SizedBox(height: 12),
                Text(l.uiLabTypeCaption, style: t.textTheme.bodySmall),
              ],
            ),
          ),
        ),
        _Section('03', l.uiLabRhythm, l.uiLabRhythmHint),
        _Surface(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 24,
                  runSpacing: 16,
                  children: [
                    for (final size in [8, 16, 24])
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: size * 3,
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('$size dp', style: t.textTheme.bodySmall),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(l.uiLabRadii, style: t.textTheme.bodyMedium),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final icon in [
                      Icons.chat_bubble_outline_rounded,
                      Icons.tune_rounded,
                      Icons.graphic_eq_rounded,
                      Icons.inventory_2_outlined,
                    ])
                      _IconDisc(icon),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _controls(BuildContext context) {
    final l = context.l10n;
    final c = Theme.of(context).colorScheme;
    return ListView(
      key: const PageStorageKey('ui_lab_control_list'),
      padding: const EdgeInsets.all(20),
      children: [
        Text(l.uiLabLocalOnly, style: Theme.of(context).textTheme.bodySmall),
        _Section('01', l.uiLabActions, l.uiLabActionsHint),
        _Surface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => _feedback(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.uiLabPrimaryAction),
                ),
                FilledButton.tonal(
                  onPressed: () => _feedback(context),
                  child: Text(l.uiLabSecondaryAction),
                ),
                OutlinedButton(
                  onPressed: () => _models(context),
                  child: Text(l.uiLabSheet),
                ),
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l.uiLabDialogTitle),
                        content: Text(l.uiLabDialogBody),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(l.commonCancel),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(l.uiLabConfirm),
                          ),
                        ],
                      ),
                    );
                    if (context.mounted && confirmed == true) {
                      _feedback(context);
                    }
                  },
                  child: Text(l.uiLabDialog),
                ),
                FilledButton(onPressed: null, child: Text(l.uiLabDisabled)),
              ],
            ),
          ),
        ),
        _Section('02', l.uiLabForms, l.uiLabFormsHint),
        _Surface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  key: const Key('ui_lab_name'),
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l.uiLabName,
                    hintText: l.uiLabNameHint,
                    errorText: _invalid ? l.uiLabNameError : null,
                  ),
                  onChanged: (_) {
                    if (_invalid) setState(() => _invalid = false);
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile.adaptive(
                  key: const Key('ui_lab_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.uiLabStreaming),
                  subtitle: Text(l.uiLabStreamingHint),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                const Divider(),
                const SizedBox(height: 16),
                NumericSlider(
                  label: l.uiLabTemperature,
                  value: _temperature,
                  min: 0,
                  max: 1,
                  divisions: 10,
                  onChanged: (value) => setState(() => _temperature = value),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: Text(l.uiLabVision),
                        selected: _vision,
                        onSelected: (value) => setState(() => _vision = value),
                      ),
                      ActionChip(
                        label: Text(
                          _model == 0 ? 'Qwen3 · 4B' : 'Gemini · Flash',
                        ),
                        avatar: const Icon(Icons.memory_outlined, size: 16),
                        onPressed: () => _models(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    key: const Key('ui_lab_validate'),
                    onPressed: () {
                      setState(() => _invalid = _name.text.trim().isEmpty);
                      if (!_invalid) _feedback(context);
                    },
                    child: Text(l.uiLabValidate),
                  ),
                ),
              ],
            ),
          ),
        ),
        _Section('03', l.uiLabMessages, l.uiLabMessagesHint),
        _Surface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                for (final (tone, label, message, icon) in [
                  (
                    AppMessageTone.success,
                    l.uiLabMessageSuccess,
                    l.uiLabFeedback,
                    Icons.check_circle_outline_rounded,
                  ),
                  (
                    AppMessageTone.info,
                    l.uiLabMessageInfo,
                    l.uiLabMessageInfoText,
                    Icons.info_outline_rounded,
                  ),
                  (
                    AppMessageTone.warning,
                    l.uiLabMessageWarning,
                    l.uiLabMessageWarningText,
                    Icons.warning_amber_rounded,
                  ),
                  (
                    AppMessageTone.error,
                    l.uiLabMessageError,
                    l.uiLabMessageErrorText,
                    Icons.error_outline_rounded,
                  ),
                ])
                  OutlinedButton.icon(
                    key: ValueKey('ui_lab_message_${tone.name}'),
                    onPressed: () =>
                        AppMessageHost.of(context).show(message, tone: tone),
                    icon: Icon(icon, size: 18),
                    label: Text(label),
                  ),
              ],
            ),
          ),
        ),
        _Section('04', l.uiLabStates, l.uiLabStatesHint),
        _Surface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _status(
                      context,
                      l.uiLabReady,
                      Icons.check_circle_outline,
                      false,
                    ),
                    _status(
                      context,
                      l.uiLabWaiting,
                      Icons.schedule_rounded,
                      true,
                    ),
                    _Badge(l.uiLabFailed, c.onErrorContainer, c.errorContainer),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: Text(l.uiLabDownload)),
                    Text(
                      '${(_progress * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _transfer,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(_progress >= 1 ? l.uiLabAgain : l.uiLabSimulate),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _scenes(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context);
    final c = t.colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const PageStorageKey('ui_lab_scene_list'),
            controller: _sceneScroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              _Section('01', l.uiLabChat, l.uiLabChatHint),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(l.uiLabYou, style: t.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: c.primaryContainer,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(_sent ?? l.uiLabQuestion),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const _IconDisc(Icons.auto_awesome_outlined, primary: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.uiLabAssistant,
                      style: t.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Surface(
                tonal: true,
                child: ExpansionTile(
                  key: const Key('ui_lab_tool'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: Icon(
                    Icons.travel_explore_rounded,
                    size: 20,
                    color: c.primary,
                  ),
                  title: Text(l.uiLabTool, style: t.textTheme.bodyMedium),
                  children: [
                    Text(l.uiLabToolDetail, style: t.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _sent == null ? l.uiLabAnswer : l.uiLabReply,
                style: t.textTheme.bodyLarge,
              ),
              const SizedBox(height: 14),
              Text(
                '10:24 · ${_model == 0 ? 'Qwen3 · 4B' : 'Gemini · Flash'}',
                style: t.textTheme.bodySmall,
              ),
              Row(
                children: [
                  IconButton(
                    tooltip: l.uiLabCopy,
                    onPressed: () => _feedback(context),
                    icon: const Icon(Icons.copy_outlined, size: 18),
                  ),
                  IconButton(
                    tooltip: l.uiLabAgain,
                    onPressed: () => setState(() => _sent = null),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: l.uiLabMore,
                    onPressed: () => _models(context),
                    icon: const Icon(Icons.more_horiz_rounded, size: 20),
                  ),
                ],
              ),
              _Section('02', l.uiLabManagement, l.uiLabManagementHint),
              _Surface(
                child: Column(
                  children: [
                    ListTile(
                      leading: const _IconDisc(
                        Icons.person_outline_rounded,
                        primary: true,
                      ),
                      title: Text(l.uiLabAssistant),
                      subtitle: Text(l.uiLabAssistantHint),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _models(context),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 68),
                      child: Divider(),
                    ),
                    ListTile(
                      leading: const Icon(Icons.cloud_outlined),
                      title: const Text('OpenAI'),
                      subtitle: Text(l.uiLabProviderHint),
                      trailing: Switch(
                        value: _enabled,
                        onChanged: (value) => setState(() => _enabled = value),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 68),
                      child: Divider(),
                    ),
                    ListTile(
                      leading: const Icon(Icons.graphic_eq_rounded),
                      title: Text(l.uiLabVoice),
                      subtitle: Text(l.uiLabVoiceHint),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _feedback(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Surface(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const _IconDisc(Icons.memory_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Qwen3 · 4B',
                              style: t.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Badge(
                            'GGUF',
                            c.onSurfaceVariant,
                            c.surfaceContainerLow,
                          ),
                          _Badge(
                            '2.4 GB',
                            c.onSurfaceVariant,
                            c.surfaceContainerLow,
                          ),
                          _status(
                            context,
                            l.uiLabReady,
                            Icons.check_circle_outline,
                            false,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _Surface(
            outline: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    key: const Key('ui_lab_message'),
                    controller: _message,
                    minLines: 1,
                    maxLines: 3,
                    maxLength: 400,
                    decoration: InputDecoration(
                      hintText: l.uiLabComposer,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  Row(
                    children: [
                      IconButton(
                        key: const Key('ui_lab_model_picker'),
                        tooltip: l.uiLabChooseModel,
                        onPressed: () => _models(context),
                        icon: Icon(Icons.memory_outlined, color: c.primary),
                      ),
                      Expanded(
                        child: Text(
                          _model == 0 ? 'Qwen3 · 4B' : 'Gemini · Flash',
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodySmall,
                        ),
                      ),
                      IconButton(
                        tooltip: l.uiLabVoice,
                        onPressed: () => _feedback(context),
                        icon: const Icon(Icons.mic_none_rounded),
                      ),
                      IconButton.filledTonal(
                        key: const Key('ui_lab_send'),
                        tooltip: l.uiLabSend,
                        onPressed: _message.text.trim().isEmpty
                            ? null
                            : () {
                                setState(() {
                                  _sent = _message.text.trim();
                                  _message.clear();
                                });
                                FocusManager.instance.primaryFocus?.unfocus();
                                _sceneScroll.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                );
                              },
                        icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _status(
    BuildContext context,
    String text,
    IconData icon,
    bool warning,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Color(
      warning
          ? (dark ? 0xFFE9C37B : 0xFF80601F)
          : (dark ? 0xFF9DD9B9 : 0xFF32654D),
    );
    final background = Color(
      warning
          ? (dark ? 0xFF3D3422 : 0xFFF8F0DB)
          : (dark ? 0xFF23392F : 0xFFE6F3EC),
    );
    return _Badge(text, foreground, background, icon: icon);
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.tonal = false,
    this.outline = false,
  });
  final Widget child;
  final bool tonal;
  final bool outline;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Material(
      color: tonal ? c.surfaceContainerLow : c.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PreviewTheme.cardRadius),
        side: outline ? BorderSide(color: c.outlineVariant) : BorderSide.none,
      ),
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.number, this.title, this.hint);
  final String number;
  final String title;
  final String hint;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(number, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(hint, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.foreground, this.background, {this.icon});
  final String text;
  final Color foreground;
  final Color background;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          if (icon != null)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(icon, size: 14, color: foreground),
              ),
            ),
          TextSpan(text: text),
        ],
      ),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: foreground),
    ),
  );
}

class _IconDisc extends StatelessWidget {
  const _IconDisc(this.icon, {this.primary = false});
  final IconData icon;
  final bool primary;
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: primary ? c.primaryContainer : c.surfaceContainerLow,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 20,
        color: primary ? c.primary : c.onSurfaceVariant,
      ),
    );
  }
}
