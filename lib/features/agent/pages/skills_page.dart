import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/pages/skill_detail_page.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/agent/widgets/skill_errors.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/shared/widgets/async_action.dart';

enum _SkillImportAction { paste, file }

class SkillsPage extends StatefulWidget {
  const SkillsPage({super.key});
  @override
  State<SkillsPage> createState() => _SkillsPageState();
}

class _SkillsPageState extends State<SkillsPage> {
  final search = TextEditingController();
  List<SkillRecord> skills = [];
  bool loaded = false;
  @override
  void initState() {
    super.initState();
    final cached = context.read<AgentToolService>().cachedSkills;
    if (cached != null) {
      skills = cached;
      loaded = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runUiAction(context, () => reload(refresh: false));
    });
  }

  Future<void> reload({bool refresh = true}) async {
    if (!mounted) return;
    final service = context.read<AgentToolService>();
    final assistants = context.read<AssistantProvider>();
    try {
      final records = await (refresh
          ? service.loadSkills()
          : service.ensureSkillsLoaded());
      if (refresh) await assistants.load();
      if (mounted) setState(() => skills = records);
    } finally {
      if (mounted) setState(() => loaded = true);
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _showAddMenu() async {
    final l = context.l10n;
    final action = await showModalBottomSheet<_SkillImportAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('skills_import_paste'),
              leading: const Icon(Icons.content_paste_outlined),
              title: Text(l.v2SkillImportPaste),
              onTap: () =>
                  Navigator.pop(sheetContext, _SkillImportAction.paste),
            ),
            ListTile(
              key: const Key('skills_import_file'),
              leading: const Icon(Icons.upload_file_outlined),
              title: Text(l.v2SkillImportFile),
              onTap: () => Navigator.pop(sheetContext, _SkillImportAction.file),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _SkillImportAction.paste:
        await _showPasteImport();
      case _SkillImportAction.file:
        await _importFromFile();
    }
  }

  Future<void> _importFromFile() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final service = context.read<AgentToolService>();
    await runUiAction(context, () async {
      final imported = await service.importSkillFromFile();
      if (imported != null && mounted) await reload();
    });
  }

  Future<void> _showPasteImport() async {
    final service = context.read<AgentToolService>();
    final imported = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: _PasteSkillSheet(
            onImport: service.importSkillFromText,
            errorMessage: skillFormatErrorMessage,
          ),
        ),
      ),
    );
    if (imported == true && mounted) await runUiAction(context, reload);
  }

  Future<void> _open(SkillRecord skill) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => SkillDetailPage(skillId: skill.id)),
    );
    if (mounted) await runUiAction(context, reload);
  }

  Future<void> _setEnabled(SkillRecord skill, bool enabled) async {
    final service = context.read<AgentToolService>();
    await runUiAction(context, () async {
      await service.setSkillEnabled(skill, enabled);
      await reload();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final query = search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? skills
        : skills
              .where(
                (skill) =>
                    skill.name.toLowerCase().contains(query) ||
                    skill.description.toLowerCase().contains(query),
              )
              .toList();
    return AppScaffold(
      appBar: AppBar(
        title: Text(l.v2Skills),
        actions: [
          IconButton(
            key: const Key('skills_add_button'),
            tooltip: l.v2ImportSkill,
            icon: const Icon(Icons.add),
            onPressed: _showAddMenu,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => runUiAction(context, reload),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (!loaded)
                const SliverToBoxAdapter(child: LinearProgressIndicator()),
              if (loaded && skills.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.extension_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.v2SkillsEmpty,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.v2SkillsEmptyHint,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (skills.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  sliver: SliverToBoxAdapter(
                    child: TextField(
                      key: const Key('skills_search'),
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: l.v2SkillSearchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l.v2SkillSearchClear,
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(search.clear),
                              ),
                      ),
                    ),
                  ),
                ),
              if (skills.isNotEmpty && visible.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
                    child: Text(
                      l.v2SkillNoResults,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              if (visible.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  sliver: SliverList.list(
                    children: [
                      for (final skill in visible)
                        _SkillTile(
                          skill: skill,
                          onTap: () => _open(skill),
                          onEnabled: (enabled) => _setEnabled(skill, enabled),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.skill,
    required this.onTap,
    required this.onEnabled,
  });

  final SkillRecord skill;
  final VoidCallback onTap;
  final ValueChanged<bool> onEnabled;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final valid = skill.hasValidMetadata;
    return Card(
      child: ListTile(
        key: ValueKey('skill_${skill.id}'),
        leading: const Icon(Icons.extension_outlined),
        title: Text(skill.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              skill.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!valid)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  l.v2SkillMetadataIncomplete,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            if (skill.hasScripts)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  l.v2ScriptsUnsupported,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        trailing: Switch.adaptive(
          key: ValueKey('skill_enabled_${skill.id}'),
          value: skill.enabled,
          onChanged: valid ? onEnabled : null,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _PasteSkillSheet extends StatefulWidget {
  const _PasteSkillSheet({required this.onImport, required this.errorMessage});

  final Future<SkillRecord> Function(String markdown) onImport;
  final String Function(AppLocalizations l, Object error) errorMessage;

  @override
  State<_PasteSkillSheet> createState() => _PasteSkillSheetState();
}

class _PasteSkillSheetState extends State<_PasteSkillSheet> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _canSubmit => !_busy && _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onImport(_controller.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final l = context.l10n;
      setState(() {
        _busy = false;
        _error = error is FormatException
            ? widget.errorMessage(l, error)
            : '${l.v2OperationFailed}\n${LogRedactor.redact(error.toString())}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.v2SkillImportPasteTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          key: const Key('skills_paste_field'),
          controller: _controller,
          enabled: !_busy,
          autofocus: true,
          minLines: 8,
          maxLines: 16,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: l.v2SkillMarkdownLabel,
            hintText: l.v2SkillImportMarkdownHint,
            alignLabelWithHint: true,
          ),
          onChanged: (_) => setState(() => _error = null),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            key: const Key('skills_paste_error'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: Text(l.commonCancel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('skills_paste_submit'),
              onPressed: _canSubmit ? _submit : null,
              child: _busy
                  ? SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimary,
                      ),
                    )
                  : Text(l.v2SkillImportConfirm),
            ),
          ],
        ),
      ],
    );
  }
}
