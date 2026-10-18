import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/services/downloads_export_service.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/pages/skill_editor_page.dart';
import 'package:servllama/features/agent/pages/skill_file_page.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/app_message.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:servllama/shared/widgets/async_action.dart';
import 'package:servllama/shared/widgets/form_list_view.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/settings_tile_list.dart';
import 'package:servllama/shared/widgets/switch_setting_tile.dart';

enum _SkillAction { edit, export, delete }

class SkillDetailPage extends StatefulWidget {
  const SkillDetailPage({super.key, required this.skillId});

  final String skillId;

  @override
  State<SkillDetailPage> createState() => _SkillDetailPageState();
}

class _SkillDetailPageState extends State<SkillDetailPage> {
  SkillRecord? skill;
  List<SkillFileEntry> files = const [];
  String? body;
  bool loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final service = context.read<AgentToolService>();
    try {
      final records = await service.loadSkills();
      final found = records
          .where((record) => record.id == widget.skillId)
          .firstOrNull;
      if (found == null) throw StateError('Skill not found');
      final details = await service.loadSkillDetails(found);
      final markdown = await service.readSkillText(found);
      if (!mounted || generation != _generation) return;
      setState(() {
        skill = details.record;
        files = details.files;
        body = _markdownBody(markdown);
        loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => loading = false);
      AppMessage.show(
        context,
        context.l10n.v2SkillLoadFailed,
        tone: AppMessageTone.error,
      );
    }
  }

  Future<void> _setEnabled(bool enabled) async {
    final current = skill;
    if (current == null) return;
    final service = context.read<AgentToolService>();
    await runUiAction(context, () async {
      final updated = await service.setSkillEnabled(current, enabled);
      if (mounted) setState(() => skill = updated);
    });
  }

  Future<void> _edit() async {
    final current = skill;
    if (current == null) return;
    final updated = await Navigator.push<SkillRecord>(
      context,
      MaterialPageRoute(builder: (_) => SkillEditorPage(skill: current)),
    );
    if (updated != null && mounted) await _load();
  }

  Future<void> _export() async {
    final current = skill;
    if (current == null) return;
    final service = context.read<AgentToolService>();
    final output = await Directory.systemTemp.createTemp(
      'servllama_skill_export_',
    );
    if (!mounted) {
      await output.delete(recursive: true);
      return;
    }
    try {
      await runUiAction(context, () async {
        final archive = await service.exportSkill(current, output);
        final saved = await DownloadsExportService().saveFile(
          source: archive,
          fileName: '${current.id}.zip',
          mimeType: 'application/zip',
        );
        if (mounted) {
          AppMessage.show(
            context,
            context.l10n.v2SkillExported(saved),
            tone: AppMessageTone.success,
          );
        }
      });
    } finally {
      if (await output.exists()) await output.delete(recursive: true);
    }
  }

  Future<void> _delete() async {
    final current = skill;
    if (current == null) return;
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.v2SkillDeleteTitle(current.name)),
        content: Text(l.v2SkillDeleteCannotUndo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await runUiAction(context, () async {
      await context.read<AgentToolService>().deleteSkill(current);
      if (mounted) Navigator.pop(context, true);
    });
  }

  Future<void> _openFile(SkillFileEntry file) async {
    final current = skill;
    if (current == null || !file.isText) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => SkillFilePage(skill: current, file: file),
      ),
    );
  }

  void _action(_SkillAction action) {
    switch (action) {
      case _SkillAction.edit:
        _edit();
      case _SkillAction.export:
        _export();
      case _SkillAction.delete:
        _delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final current = skill;
    final resources = files
        .where((file) => file.relativePath != 'SKILL.md')
        .toList();
    return AppScaffold(
      appBar: AppBar(
        title: Text(current?.name ?? l.v2Skills),
        actions: [
          if (current != null)
            PopupMenuButton<_SkillAction>(
              tooltip: l.v2SkillMoreActions,
              onSelected: _action,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _SkillAction.edit,
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined),
                      const SizedBox(width: 12),
                      Text(l.v2SkillEdit),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _SkillAction.export,
                  child: Row(
                    children: [
                      const Icon(Icons.ios_share_outlined),
                      const SizedBox(width: 12),
                      Text(l.v2SkillExport),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _SkillAction.delete,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Text(l.v2SkillDelete),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : current == null
          ? Center(child: Text(l.v2SkillLoadFailed))
          : FormListView(
              children: [
                SettingsSection(
                  title: l.v2SkillStatus,
                  child: SwitchSettingTile(
                    title: current.enabled
                        ? l.v2SkillEnabled
                        : l.v2SkillDisabled,
                    subtitle: current.hasValidMetadata
                        ? null
                        : l.v2SkillMetadataIncomplete,
                    value: current.enabled,
                    onChanged: current.hasValidMetadata ? _setEnabled : null,
                  ),
                ),
                SettingsSection(
                  title: l.v2SkillDescription,
                  child: Text(
                    current.description,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (current.hasScripts)
                  SettingsSection(
                    title: l.v2SkillMetadata,
                    child: SettingsTileList(
                      children: [
                        _MetadataRow(
                          icon: Icons.code_outlined,
                          label: l.v2SkillScripts,
                          value: l.v2ScriptsUnsupported,
                        ),
                      ],
                    ),
                  ),
                SettingsSection(
                  title: l.v2SkillMarkdownLabel,
                  child: body == null || body!.isEmpty
                      ? Text(l.v2SkillDetailBodyEmpty)
                      : GptMarkdown(
                          body!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.55),
                        ),
                ),
                SettingsSection(
                  title: l.v2SkillResources,
                  child: resources.isEmpty
                      ? Text(l.v2SkillNoResources)
                      : SettingsTileList(
                          children: [
                            for (final file in resources)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                enabled: file.isText,
                                leading: Icon(
                                  file.isText
                                      ? Icons.description_outlined
                                      : Icons.insert_drive_file_outlined,
                                ),
                                title: Text(
                                  file.relativePath,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(_formatBytes(file.size)),
                                trailing: file.isText
                                    ? const Icon(Icons.chevron_right)
                                    : null,
                                onTap: file.isText
                                    ? () => _openFile(file)
                                    : null,
                              ),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value, maxLines: 3, overflow: TextOverflow.ellipsis),
    );
  }
}

String _markdownBody(String markdown) {
  final front = RegExp(r'^---\r?\n[\s\S]*?\r?\n---\r?\n?').firstMatch(markdown);
  return (front == null ? markdown : markdown.substring(front.end)).trim();
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  return '$bytes B';
}
