import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/agent/widgets/skill_errors.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:servllama/shared/widgets/form_list_view.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

class SkillEditorPage extends StatefulWidget {
  const SkillEditorPage({super.key, required this.skill});

  final SkillRecord skill;

  @override
  State<SkillEditorPage> createState() => _SkillEditorPageState();
}

class _SkillEditorPageState extends State<SkillEditorPage> {
  final controller = TextEditingController();
  String? original;
  String? error;
  bool saving = false;

  bool get dirty => original != null && controller.text != original;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final l = context.l10n;
    try {
      final text = await context.read<AgentToolService>().readSkillText(
        widget.skill,
      );
      if (!mounted) return;
      setState(() {
        original = text;
        controller.text = text;
      });
    } catch (cause) {
      if (!mounted) return;
      setState(() => error = skillFormatErrorMessage(l, cause));
    }
  }

  Future<void> _save() async {
    if (saving || original == null) return;
    final l = context.l10n;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final updated = await context.read<AgentToolService>().updateSkill(
        widget.skill,
        controller.text,
      );
      if (mounted) Navigator.pop(context, updated);
    } catch (cause) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = skillFormatErrorMessage(l, cause);
      });
    }
  }

  Future<void> _confirmDiscard() async {
    final l = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.v2SkillDiscardChanges),
        content: Text(l.v2SkillDiscardChangesHelp),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.v2SkillDiscard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return PopScope(
      canPop: !dirty && !saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && dirty && !saving) _confirmDiscard();
      },
      child: AppScaffold(
        appBar: AppBar(
          title: Text(widget.skill.name),
          actions: [
            TextButton(
              onPressed: original == null || saving ? null : _save,
              child: saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l.commonSave),
            ),
          ],
        ),
        body: original == null && error == null
            ? const LinearProgressIndicator()
            : FormListView(
                children: [
                  SettingsSection.form(
                    title: l.v2SkillMarkdownLabel,
                    children: [
                      TextField(
                        key: const Key('skill_editor_markdown'),
                        controller: controller,
                        enabled: !saving,
                        minLines: 16,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: l.v2SkillImportMarkdownHint,
                          errorText: error,
                        ),
                        onChanged: (_) => setState(() => error = null),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
