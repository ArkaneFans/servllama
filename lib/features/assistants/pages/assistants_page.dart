import 'dart:async';

import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/form_list_view.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:servllama/features/agent/widgets/assistant_tools_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/widgets/avatar_editor.dart';
import 'package:servllama/features/assistants/widgets/identity_avatar.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/features/chat/pages/chat_target_picker.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/shared/widgets/async_action.dart';

class AssistantsPage extends StatefulWidget {
  const AssistantsPage({super.key});

  @override
  State<AssistantsPage> createState() => _AssistantsPageState();
}

class _AssistantsPageState extends State<AssistantsPage> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AssistantProvider>();
    final chat = context.watch<ChatProvider?>();
    final l = context.l10n;
    final query = search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? p.assistants
        : p.assistants
              .where((a) => a.name.toLowerCase().contains(query))
              .toList();
    return AppScaffold(
      appBar: AppBar(
        title: Text(l.v2AssistantManagement),
        actions: [
          IconButton(
            key: const Key('assistant_add'),
            tooltip: l.v2Add,
            icon: const Icon(Icons.add),
            onPressed: () => _add(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: p.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            if (p.error != null)
              ListTile(
                title: Text(l.v2OperationFailed),
                subtitle: Text(p.error!),
              ),
            if (!p.loaded) const LinearProgressIndicator(),
            if (p.assistants.isNotEmpty) ...[
              TextField(
                key: const Key('assistant_search'),
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l.v2AssistantSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('assistant_search_clear'),
                          tooltip: l.v2AssistantSearchClear,
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(search.clear),
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (p.assistants.isNotEmpty && visible.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 36, 12, 36),
                child: Text(
                  l.v2AssistantNoResults,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ...visible.map(
              (a) => Card(
                child: ListTile(
                  leading: IdentityAvatar(
                    value: a.avatar,
                    name: a.name,
                    size: 40,
                  ),
                  title: Text(
                    a.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _edit(context, a),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => runUiAction(context, () async {
                      switch (value) {
                        case 'copy':
                          await p.duplicate(a);
                        case 'delete':
                          await _delete(context, a);
                      }
                    }),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'copy', child: Text(l.v2Duplicate)),
                      PopupMenuItem(
                        enabled: chat?.canManageSessions ?? false,
                        value: 'delete',
                        child: Text(l.commonDelete),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Assistant assistant) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AssistantEditor(assistant: assistant),
        ),
      );

  Future<void> _add(BuildContext context) async {
    final name = await _showAddAssistantSheet(context);
    if (name == null || !context.mounted) return;
    final provider = context.read<AssistantProvider>();
    final assistant = Assistant(id: newId(), name: name);
    var created = false;
    await runUiAction(context, () async {
      await provider.save(assistant);
      created = true;
    });
    if (!context.mounted || !created) return;
    final saved = provider.assistants
        .where((item) => item.id == assistant.id)
        .firstOrNull;
    if (saved == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AssistantEditor(assistant: saved),
      ),
    );
  }

  Future<String?> _showAddAssistantSheet(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const _AddAssistantSheet(),
    );
  }

  Future<void> _delete(BuildContext context, Assistant assistant) async {
    final provider = context.read<AssistantProvider>();
    final chat = context.read<ChatProvider>();
    if (!chat.canManageSessions) return;
    final l = context.l10n;
    if (provider.assistants.length <= 1) {
      throw StateError(l.v2KeepOneAssistant);
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(assistant.name),
        content: Text(l.v2DeleteAssistantHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await chat.deleteAssistant(assistant.id);
  }
}

class _AddAssistantSheet extends StatefulWidget {
  const _AddAssistantSheet();

  @override
  State<_AddAssistantSheet> createState() => _AddAssistantSheetState();
}

class _AddAssistantSheetState extends State<_AddAssistantSheet> {
  final controller = TextEditingController();
  String? error;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = controller.text.trim();
    if (name.isEmpty) {
      setState(() => error = context.l10n.v2AssistantNameRequired);
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.v2AssistantAddTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('assistant_add_name'),
                controller: controller,
                autofocus: true,
                maxLength: 120,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l.v2Name,
                  errorText: error,
                ),
                onChanged: (_) {
                  if (error != null) setState(() => error = null);
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('assistant_add_button'),
                onPressed: _submit,
                icon: const Icon(Icons.add_rounded),
                label: Text(l.v2Add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AssistantEditor extends StatefulWidget {
  const AssistantEditor({super.key, required this.assistant});
  final Assistant assistant;
  @override
  State<AssistantEditor> createState() => _AssistantEditorState();
}

class _AssistantEditorState extends State<AssistantEditor> {
  static const _textSaveDelay = Duration(milliseconds: 400);
  late AssistantProvider _provider;
  late final name = TextEditingController(text: widget.assistant.name);
  late final instructions = TextEditingController(
    text: widget.assistant.instructions,
  );
  late String _savedName = widget.assistant.name;
  late String _savedInstructions = widget.assistant.instructions;
  Timer? _textSaveTimer;
  Future<void> _saveQueue = Future.value();
  bool _allowPop = false;
  bool _popScheduled = false;
  String? _nameError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = context.read<AssistantProvider>();
  }

  @override
  void dispose() {
    _textSaveTimer?.cancel();
    if (name.text.trim().isNotEmpty) {
      final changes = _textChanges();
      if (changes.isNotEmpty) unawaited(_saveFields(changes));
    }
    name.dispose();
    instructions.dispose();
    super.dispose();
  }

  void _queueTextSave() {
    _textSaveTimer?.cancel();
    _textSaveTimer = Timer(
      _textSaveDelay,
      () => unawaited(_commitTextFields()),
    );
  }

  Map<String, dynamic> _textChanges() {
    final changes = <String, dynamic>{};
    final trimmed = name.text.trim();
    if (trimmed.isNotEmpty && trimmed != _savedName) {
      changes['name'] = trimmed;
    }
    if (instructions.text != _savedInstructions) {
      changes['instructions'] = instructions.text;
    }
    return changes;
  }

  Future<bool> _commitTextFields() async {
    _textSaveTimer?.cancel();
    final trimmed = name.text.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() => _nameError = context.l10n.v2AssistantNameRequired);
      }
      return false;
    }
    final changes = _textChanges();
    if (changes.isEmpty) return true;
    final saved = await _saveFields(changes);
    if (!saved) return false;
    if (changes.containsKey('name')) _savedName = changes['name'] as String;
    if (changes.containsKey('instructions')) {
      _savedInstructions = changes['instructions'] as String;
    }
    return true;
  }

  Future<bool> _saveFields(Map<String, dynamic> changes) {
    final result = _saveQueue.then((_) async {
      if (!mounted) {
        try {
          await _provider.updateAssistant(widget.assistant.id, changes);
          return true;
        } catch (_) {
          return false;
        }
      }
      var saved = false;
      await runUiAction(context, () async {
        await _provider.updateAssistant(widget.assistant.id, changes);
        saved = true;
      });
      return saved;
    });
    _saveQueue = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  Future<void> _flushAndPop() async {
    if (_popScheduled) return;
    _popScheduled = true;
    final valid = await _commitTextFields();
    await _saveQueue;
    if (!mounted) return;
    if (!valid) {
      _popScheduled = false;
      return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.watch<AssistantProvider>();
    final current =
        p.assistants
            .where((assistant) => assistant.id == widget.assistant.id)
            .firstOrNull ??
        widget.assistant;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_flushAndPop());
      },
      child: AppScaffold(
        appBar: AppBar(
          title: Text(
            name.text.trim().isEmpty ? l.v2AssistantEditor : name.text.trim(),
          ),
        ),
        body: FormListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            SettingsSection.form(
              title: l.v2IdentitySettings,
              children: [
                AvatarEditor(
                  value: current.avatar,
                  name: name.text,
                  centered: true,
                  onChanged: (value) =>
                      unawaited(_saveFields({'avatar': value})),
                  onBusyChanged: (_) {},
                ),
                TextField(
                  key: const Key('assistant_name'),
                  controller: name,
                  onChanged: (_) {
                    setState(() => _nameError = null);
                    _queueTextSave();
                  },
                  onSubmitted: (_) => unawaited(_commitTextFields()),
                  decoration: InputDecoration(
                    labelText: l.v2Name,
                    errorText: _nameError,
                  ),
                ),
              ],
            ),
            SettingsSection.form(
              title: l.v2Instructions,
              children: [
                TextField(
                  key: const Key('assistant_instructions'),
                  controller: instructions,
                  minLines: 3,
                  maxLines: 8,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => _queueTextSave(),
                  onSubmitted: (_) => unawaited(_commitTextFields()),
                  decoration: InputDecoration(
                    hintText: l.v2InstructionsHint,
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            SettingsSection.form(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.v2AssistantDefaultModel),
                  subtitle: Text(
                    current.chatTarget == null
                        ? l.v2NoDefaultModel
                        : !current.chatTarget!.isConfigured
                        ? l.v2MissingTarget
                        : current.chatTarget!.isRemote
                        ? '${p.connection(current.chatTarget!.connectionId)?.name ?? l.v2MissingTarget} / ${current.chatTarget!.modelId}'
                        : p.assets
                                  .where(
                                    (asset) =>
                                        asset.id == current.chatTarget!.assetId,
                                  )
                                  .firstOrNull
                                  ?.name ??
                              l.v2MissingTarget,
                  ),
                  onTap: () async {
                    final selected = await showChatTargetPicker(
                      context,
                      initialTarget: current.chatTarget,
                    );
                    if (mounted &&
                        selected != null &&
                        selected != current.chatTarget) {
                      await _saveFields({'chatTarget': selected.toJson()});
                    }
                  },
                  trailing: current.chatTarget == null
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          tooltip: l.v2ClearDefaultModel,
                          onPressed: () => _saveFields({'chatTarget': null}),
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ],
            ),

            SettingsSection(
              padding: const EdgeInsets.all(16),
              child: AssistantToolsEditor(
                assistant: current,
                onChanged: (changes) => unawaited(_saveFields(changes)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
