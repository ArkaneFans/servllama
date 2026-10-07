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

class AssistantsPage extends StatelessWidget {
  const AssistantsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AssistantProvider>();
    final chat = context.watch<ChatProvider?>();
    final l = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(l.v2AssistantManagement)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.v2Add,
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: p.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
          children: [
            if (p.error != null)
              ListTile(
                title: Text(l.v2OperationFailed),
                subtitle: Text(p.error!),
              ),
            if (!p.loaded) const LinearProgressIndicator(),
            ...p.assistants.map(
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

  Future<void> _edit(BuildContext context, Assistant? assistant) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AssistantEditor(assistant: assistant),
        ),
      );

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

class AssistantEditor extends StatefulWidget {
  const AssistantEditor({super.key, this.assistant});
  final Assistant? assistant;
  @override
  State<AssistantEditor> createState() => _AssistantEditorState();
}

class _AssistantEditorState extends State<AssistantEditor> {
  late final Assistant original =
      widget.assistant ?? Assistant(id: newId(), name: '');
  late final name = TextEditingController(text: original.name);
  late String avatar = original.avatar;
  late final instructions = TextEditingController(text: original.instructions);
  late ChatTarget? chatTarget = original.chatTarget;
  bool modelEdited = false;
  final toolsKey = GlobalKey<AssistantToolsEditorState>();
  bool saving = false, avatarBusy = false;
  @override
  void dispose() {
    name.dispose();
    instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.watch<AssistantProvider>();
    if (!modelEdited && widget.assistant != null) {
      chatTarget = p.assistants
          .where((a) => a.id == original.id)
          .firstOrNull
          ?.chatTarget;
    }
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          name.text.trim().isEmpty ? l.v2AssistantEditor : name.text.trim(),
        ),
        actions: [
          TextButton(
            onPressed: saving || avatarBusy
                ? null
                : () => runUiAction(context, () async {
                    setState(() => saving = true);
                    try {
                      final changes = {
                        'name': name.text.trim(),
                        'avatar': avatar,
                        'instructions': instructions.text,
                        if (modelEdited || widget.assistant == null)
                          'chatTarget': chatTarget?.toJson(),
                        ...await toolsKey.currentState?.changes() ??
                            <String, dynamic>{},
                      };
                      if (!mounted) return;
                      final current = widget.assistant == null
                          ? original
                          : (await (await p.repository).assistants())
                                .where((a) => a.id == original.id)
                                .firstOrNull;
                      if (current == null) {
                        throw StateError('Assistant removed');
                      }
                      if (!mounted) return;
                      if (modelEdited &&
                          current.chatTarget != original.chatTarget) {
                        throw StateError(l.v2AssistantModelChanged);
                      }
                      await p.save(
                        current.changed({
                          ...changes,
                          'revision': current.revision + 1,
                        }),
                        expectedRevision: widget.assistant == null
                            ? null
                            : current.revision,
                      );
                      if (context.mounted) Navigator.pop(context);
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  }),
            child: Text(l.commonSave),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: saving,
        child: FormListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            SettingsSection.form(
              title: l.v2IdentitySettings,
              children: [
                AvatarEditor(
                  value: avatar,
                  name: name.text,
                  centered: true,
                  enabled: !saving,
                  onChanged: (value) => setState(() => avatar = value),
                  onBusyChanged: (value) => setState(() => avatarBusy = value),
                ),
                TextField(
                  controller: name,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(labelText: l.v2Name),
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
                    chatTarget == null
                        ? l.v2NoDefaultModel
                        : !chatTarget!.isConfigured
                        ? l.v2MissingTarget
                        : chatTarget!.isRemote
                        ? '${p.connection(chatTarget!.connectionId)?.name ?? l.v2MissingTarget} / ${chatTarget!.modelId}'
                        : p.assets
                                  .where((a) => a.id == chatTarget!.assetId)
                                  .firstOrNull
                                  ?.name ??
                              l.v2MissingTarget,
                  ),
                  onTap: saving
                      ? null
                      : () async {
                          final selected = await showChatTargetPicker(
                            context,
                            initialTarget: chatTarget,
                          );
                          if (mounted && selected != null) {
                            setState(() {
                              chatTarget = selected;
                              modelEdited = true;
                            });
                          }
                        },
                  trailing: chatTarget == null
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          tooltip: l.v2ClearDefaultModel,
                          onPressed: saving
                              ? null
                              : () => setState(() {
                                  chatTarget = null;
                                  modelEdited = true;
                                }),
                          icon: const Icon(Icons.clear),
                        ),
                ),
                Text(
                  l.v2AssistantDefaultModelHelp,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            SettingsSection(
              padding: const EdgeInsets.all(16),
              child: AssistantToolsEditor(key: toolsKey, assistant: original),
            ),
          ],
        ),
      ),
    );
  }
}
