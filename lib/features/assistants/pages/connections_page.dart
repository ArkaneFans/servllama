import 'package:servllama/shared/widgets/app_tab_bar.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/features/assistants/widgets/model_capabilities_sheet.dart';
import 'package:servllama/features/assistants/widgets/add_connection_sheet.dart';
import 'package:servllama/shared/widgets/form_list_view.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:servllama/shared/widgets/ai_identity_icon.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:servllama/features/assistants/models/provider_presets.dart';
import 'package:servllama/features/assistants/widgets/provider_model_picker.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

class ConnectionsPage extends StatefulWidget {
  const ConnectionsPage({super.key});
  @override
  State<ConnectionsPage> createState() => _ConnectionsPageState();
}

class _ConnectionsPageState extends State<ConnectionsPage> {
  final changing = <String>{};
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AssistantProvider>();
    final l = context.l10n;
    final query = search.text.trim().toLowerCase();
    final visible = p.connections
        .where(
          (c) =>
              c.name.toLowerCase().contains(query) ||
              c.models.any((m) => m.toLowerCase().contains(query)),
        )
        .toList();
    return AppScaffold(
      appBar: AppBar(
        title: Text(l.v2Connections),
        actions: [
          IconButton(
            tooltip: l.v2Add,
            icon: const Icon(Icons.add),
            onPressed: () => _add(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          TextField(
            key: const Key('provider_search'),
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: l.v2ProviderModelSearch,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l.appLogsClearSearch,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(search.clear),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                query.isEmpty ? l.v2ConnectionsEmpty : l.v2ProviderNoResults,
              ),
            ),
          ...visible.map(
            (c) => Card(
              child: ListTile(
                key: ValueKey('provider_${c.id}'),
                leading: AiIdentityIcon(providerId: c.id, providerName: c.name),
                title: Text(
                  c.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(l.v2ProviderModelCount(c.models.length)),
                onTap: changing.contains(c.id) ? null : () => _edit(context, c),
                trailing: Switch(
                  key: ValueKey('provider_enabled_${c.id}'),
                  value: c.enabled,
                  onChanged: changing.contains(c.id)
                      ? null
                      : (enabled) async {
                          setState(() => changing.add(c.id));
                          await runUiAction(
                            context,
                            () => p.saveConnection(
                              c.changed({'enabled': enabled}),
                            ),
                          );
                          if (mounted) {
                            setState(() => changing.remove(c.id));
                          }
                        },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const AddConnectionSheet(),
    );
  }

  Future<void> _edit(BuildContext context, AiConnection? c) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConnectionEditor(connection: c),
        ),
      );
}

class ConnectionEditor extends StatefulWidget {
  const ConnectionEditor({super.key, this.connection});
  final AiConnection? connection;
  @override
  State<ConnectionEditor> createState() => _ConnectionEditorState();
}

class _ConnectionEditorState extends State<ConnectionEditor>
    with SingleTickerProviderStateMixin {
  late final original =
      widget.connection ??
      AiConnection(
        id: newId(),
        name: '',
        protocol: AiProtocol.openai,
        baseUrl: '',
      );
  late final name = TextEditingController(text: original.name);
  late final url = TextEditingController(text: original.baseUrl);
  static const _defaultApiPath = '/chat/completions';
  late final apiPath = TextEditingController(
    text: original.apiPath?.trim().isNotEmpty == true
        ? original.apiPath!.trim()
        : _defaultApiPath,
  );
  final keyInput = TextEditingController();
  String _savedKey = '';
  final request = CancelToken();
  late bool enabled = original.enabled;
  late AiProtocol protocol = original.protocol;
  late final tabs = TabController(length: 2, vsync: this);
  final modelSearch = TextEditingController();
  bool busy = false, hideKey = true, _keyEdited = false;

  /// Latest stored row: model edits persist here immediately, while the
  /// configuration fields stay in a draft until the bottom save action.
  AiConnection _stored(AssistantProvider provider) =>
      provider.connections.where((c) => c.id == original.id).firstOrNull ??
      original;

  /// Configuration draft; models and capabilities are not part of it.
  AiConnection _draft(AiConnection stored) => stored.changed({
    'name': name.text.trim(),
    'protocol': protocol.name,
    'baseUrl': url.text.trim(),
    'apiPath': protocol == AiProtocol.openai && apiPath.text.trim().isNotEmpty
        ? apiPath.text.trim()
        : null,
    'enabled': enabled,
  });
  @override
  void initState() {
    super.initState();
    _loadSavedKey();
  }

  Future<void> _loadSavedKey() async {
    if (original.secretRef == null) return;
    try {
      final value = await context.read<AssistantProvider>().credential(
        original,
      );
      if (!mounted) return;
      _savedKey = value;
      if (!_keyEdited) keyInput.text = value;
    } catch (_) {
      // Keep the editor usable if secure storage is temporarily unavailable.
    }
  }

  String? get _keyForSave =>
      original.secretRef != null && keyInput.text == _savedKey
      ? null
      : keyInput.text;

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    apiPath.dispose();
    keyInput.dispose();
    tabs.dispose();
    modelSearch.dispose();
    request.cancel('provider editor closed');
    super.dispose();
  }

  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    await runUiAction(context, action);
    if (mounted) setState(() => busy = false);
  }

  Future<void> fetchModels(AiConnection stored) async {
    List<String>? found;
    await act(() async {
      found = await context.read<AssistantProvider>().discover(
        _draft(stored),
        keyInput.text,
        cancelToken: request,
      );
    });
    if (!mounted || found == null) return;
    final added = await showDialog<List<String>>(
      context: context,
      builder: (_) =>
          ProviderModelPicker(models: found!, existing: stored.models.toSet()),
    );
    if (!mounted || added == null || added.isEmpty) return;
    final provider = context.read<AssistantProvider>();
    final current = _stored(provider);
    final ids = added.where((id) => !current.models.contains(id)).toList();
    if (ids.isEmpty) return;
    final models = [...current.models, ...ids];
    await _saveModels(
      provider,
      current.changed({
        'models': models,
        'modelCapabilities': {
          for (final id in models)
            id: ids.contains(id)
                ? ModelCapabilities.textOnly.toJson()
                : current.capabilitiesFor(id).toJson(),
        },
      }),
    );
  }

  Future<void> addManualModel(AiConnection stored) async {
    final id = await showDialog<String>(
      context: context,
      builder: (_) => AddProviderModelDialog(existing: stored.models.toSet()),
    );
    if (!mounted || id == null) return;
    final provider = context.read<AssistantProvider>();
    final current = _stored(provider);
    final models = [...current.models, id];
    await _saveModels(
      provider,
      current.changed({
        'models': models,
        'modelCapabilities': {
          for (final model in models)
            model: model == id
                ? ModelCapabilities.textOnly.toJson()
                : current.capabilitiesFor(model).toJson(),
        },
      }),
    );
  }

  Future<void> removeModel(AiConnection stored, String id) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.v2RemoveModel),
        content: Text(l.v2RemoveModelHelp(id)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final provider = context.read<AssistantProvider>();
    final current = _stored(provider);
    if (!current.models.contains(id)) return;
    await _saveModels(
      provider,
      current.changed({
        'models': current.models.where((model) => model != id).toList(),
      }),
    );
  }

  Future<void> editCapabilities(AiConnection stored, String id) async {
    final value = await showModalBottomSheet<ModelCapabilities>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ModelCapabilitiesSheet(
        model: id,
        initial: stored.capabilitiesFor(id),
      ),
    );
    if (!mounted || value == null) return;
    final provider = context.read<AssistantProvider>();
    final current = _stored(provider);
    if (!current.models.contains(id)) return;
    await _saveModels(
      provider,
      current.changed({
        'modelCapabilities': {
          for (final model in current.models)
            model: (model == id ? value : current.capabilitiesFor(model))
                .toJson(),
        },
      }),
    );
  }

  /// Model-side edits save immediately; the configuration keeps its draft.
  Future<void> _saveModels(AssistantProvider provider, AiConnection next) =>
      act(() => provider.saveConnection(next));

  Future<void> _save(AiConnection stored) async {
    final provider = context.read<AssistantProvider>();
    await act(() async {
      await provider.saveConnection(_draft(stored), key: _keyForSave);
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _deleteProvider(AiConnection stored) async {
    final provider = context.read<AssistantProvider>();
    final references = provider.assistants
        .where((a) => a.chatTarget?.connectionId == stored.id)
        .toList();
    final conversationCount =
        await context.read<ChatProvider?>()?.countUsingConnection(stored.id) ??
        0;
    if (!mounted) return;
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(stored.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.v2DeleteConnectionHelp),
              if (conversationCount > 0)
                Text(l.v2ConnectionConversationCount(conversationCount)),
              ...references.map(
                (a) => ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: Text(a.name),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await act(() async {
      await provider.deleteConnection(stored.id);
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AssistantProvider>();
    final stored = _stored(provider);
    final l = context.l10n;
    final theme = Theme.of(context);
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          name.text.trim().isEmpty ? l.v2ConnectionEditor : name.text.trim(),
        ),
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      bottomNavigationBar: Material(
        color: theme.colorScheme.surfaceContainerLowest,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppTabBar(
              controller: tabs,
              tabs: [
                Tab(
                  key: const Key('provider_config_tab'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.tune_rounded, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l.v2ProviderConfiguration,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  key: const Key('provider_models_tab'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.view_in_ar_outlined, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l.v2Models,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: TabBarView(
          controller: tabs,
          children: [
            FormListView(
              key: const PageStorageKey('provider_configuration'),
              children: [
                SettingsSection.form(
                  title: l.v2ProviderIdentity,
                  children: [
                    TextField(
                      key: const Key('provider_name'),
                      controller: name,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: l.v2Name),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.v2ProviderEnabled),
                      value: enabled,
                      onChanged: (value) => setState(() => enabled = value),
                    ),
                  ],
                ),
                SettingsSection.form(
                  title: l.v2ProviderConnection,
                  children: [
                    DropdownButtonFormField<AiProtocol>(
                      initialValue: protocol,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l.v2Protocol),
                      items: AiProtocol.values
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(switch (v) {
                                AiProtocol.openai => l.v2ProtocolOpenai,
                                AiProtocol.anthropic => 'Anthropic',
                                AiProtocol.gemini => 'Gemini',
                              }),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => protocol = v!),
                    ),
                    TextField(
                      key: const Key('provider_url'),
                      controller: url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(labelText: l.v2BaseUrl),
                    ),
                    if (protocol == AiProtocol.openai)
                      TextField(
                        key: const Key('provider_api_path'),
                        controller: apiPath,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: l.v2ApiPath,
                          hintText: _defaultApiPath,
                        ),
                      ),
                    TextField(
                      key: const Key('provider_key'),
                      controller: keyInput,
                      obscureText: hideKey,
                      enableSuggestions: false,
                      autocorrect: false,
                      onChanged: (_) => _keyEdited = true,
                      decoration: InputDecoration(
                        labelText: l.v2ApiKey,
                        suffixIcon: IconButton(
                          key: const Key('provider_key_visibility'),
                          tooltip: hideKey ? l.v2ShowApiKey : l.v2HideApiKey,
                          onPressed: () => setState(() => hideKey = !hideKey),
                          icon: Icon(
                            hideKey
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                FilledButton.icon(
                  key: const Key('provider_save_button'),
                  onPressed: busy ? null : () => _save(stored),
                  icon: const Icon(Icons.save_outlined, size: 20),
                  label: Text(l.commonSave),
                ),
                if (!isPresetProvider(original.id))
                  OutlinedButton.icon(
                    key: const Key('provider_delete_button'),
                    onPressed: busy ? null : () => _deleteProvider(stored),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: Text(l.commonDelete),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
            _modelList(context, stored),
          ],
        ),
      ),
    );
  }

  Widget _modelList(BuildContext context, AiConnection stored) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final query = modelSearch.text.trim().toLowerCase();
    final visible = stored.models
        .where((id) => id.toLowerCase().contains(query))
        .toList();
    return CustomScrollView(
      key: const PageStorageKey('provider_models'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                TextField(
                  key: const Key('provider_models_search'),
                  controller: modelSearch,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: l.v2ModelSearch,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: modelSearch.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l.appLogsClearSearch,
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(modelSearch.clear),
                          ),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      key: const Key('provider_add_model'),
                      onPressed: busy ? null : () => addManualModel(stored),
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(l.v2AddModel),
                    ),
                    OutlinedButton.icon(
                      key: const Key('provider_fetch_models'),
                      onPressed: busy ? null : () => fetchModels(stored),
                      icon: const Icon(Icons.refresh, size: 20),
                      label: Text(l.v2FetchModels),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (visible.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.view_in_ar_outlined,
                    size: 40,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    query.isEmpty
                        ? l.v2ProviderModelsEmpty
                        : l.v2ProviderNoResults,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            sliver: SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final id = visible[index];
                final value = stored.capabilitiesFor(id);
                return Card(
                  child: ListTile(
                    key: ValueKey('provider_model_$id'),
                    leading: AiIdentityIcon(
                      model: id,
                      providerId: original.id,
                      providerName: name.text,
                    ),
                    title: Text(id),
                    subtitle: Text(modelCapabilityLabel(context, value)),
                    onTap: () => editCapabilities(stored, id),
                    trailing: IconButton(
                      tooltip: l.commonDelete,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: busy ? null : () => removeModel(stored, id),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
