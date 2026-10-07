import 'package:servllama/shared/widgets/app_tab_bar.dart';
import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/features/assistants/widgets/model_capabilities_sheet.dart';
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
      appBar: AppBar(title: Text(l.v2Connections)),
      floatingActionButton: FloatingActionButton(
        tooltip: l.v2Add,
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
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
                leading: AiIdentityIcon(
                  providerId: c.id,
                  providerName: c.name,
                  baseUrl: c.baseUrl,
                ),
                title: Text(
                  c.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${l.v2ProviderModelCount(c.models.length)} · ${isPresetProvider(c.id) ? l.v2ProviderPreset : l.v2ProviderCustom}',
                ),
                onTap: changing.contains(c.id) ? null : () => _edit(context, c),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
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
                    if (!isPresetProvider(c.id))
                      IconButton(
                        tooltip: l.commonDelete,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: changing.contains(c.id)
                            ? null
                            : () => runUiAction(
                                context,
                                () => _delete(context, c),
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, AiConnection? c) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ConnectionEditor(connection: c),
        ),
      );

  Future<void> _delete(BuildContext context, AiConnection connection) async {
    final provider = context.read<AssistantProvider>();
    final references = provider.assistants
        .where((a) => a.chatTarget?.connectionId == connection.id)
        .toList();
    final conversationCount =
        await context.read<ChatProvider?>()?.countUsingConnection(
          connection.id,
        ) ??
        0;
    if (!context.mounted) return;
    final l = context.l10n;
    if (references.isNotEmpty || conversationCount > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(connection.name),
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
      if (confirmed != true) return;
    }
    await provider.deleteConnection(connection.id);
  }
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
  final keyInput = TextEditingController();
  late final models = <String>[...original.models];
  final request = CancelToken();
  late bool enabled = original.enabled;
  late AiProtocol protocol = original.protocol;
  late final tabs = TabController(length: 2, vsync: this);
  final modelSearch = TextEditingController();
  late final capabilities = <String, ModelCapabilities>{
    for (final id in models) id: original.capabilitiesFor(id),
  };
  bool busy = false, clearKey = false;
  String? testResult;
  AiConnection get draft => original.changed({
    'name': name.text.trim(),
    'protocol': protocol.name,
    'baseUrl': url.text.trim(),
    'models': models,
    'enabled': enabled,
    'modelCapabilities': {
      for (final id in models)
        id: (capabilities[id] ?? const ModelCapabilities()).toJson(),
    },
  });
  @override
  void initState() {
    super.initState();
    for (final controller in [name, url, keyInput]) {
      controller.addListener(() {
        if (mounted && testResult != null) setState(() => testResult = null);
      });
    }
  }

  @override
  void dispose() {
    name.dispose();
    url.dispose();
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

  Future<void> fetchModels() async {
    List<String>? found;
    await act(() async {
      found = await context.read<AssistantProvider>().discover(
        draft,
        keyInput.text,
        clearKey: clearKey,
        cancelToken: request,
      );
    });
    if (!mounted || found == null) return;
    final added = await showDialog<List<String>>(
      context: context,
      builder: (_) =>
          ProviderModelPicker(models: found!, existing: models.toSet()),
    );
    if (mounted && added != null) {
      setState(() {
        for (final id in added.where((id) => !models.contains(id))) {
          models.add(id);
          capabilities[id] = ModelCapabilities.textOnly;
        }
        testResult = null;
      });
    }
  }

  Future<void> addManualModel() async {
    final id = await showDialog<String>(
      context: context,
      builder: (_) => AddProviderModelDialog(existing: models.toSet()),
    );
    if (mounted && id != null) {
      setState(() {
        models.add(id);
        capabilities[id] = ModelCapabilities.textOnly;
        testResult = null;
      });
    }
  }

  Future<void> removeModel(String id) async {
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
    if (mounted && confirmed == true) {
      setState(() {
        models.remove(id);
        capabilities.remove(id);
        testResult = null;
      });
    }
  }

  Future<void> editCapabilities(String id) async {
    final value = await showModalBottomSheet<ModelCapabilities>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ModelCapabilitiesSheet(
        model: id,
        initial: capabilities[id] ?? const ModelCapabilities(),
      ),
    );
    if (mounted && value != null) {
      setState(() {
        capabilities[id] = value;
        testResult = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<AssistantProvider>();
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
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () => act(() async {
                    await p.saveConnection(
                      draft,
                      key: keyInput.text,
                      clearKey: clearKey,
                    );
                    if (context.mounted) Navigator.pop(context);
                  }),
            child: Text(l.commonSave),
          ),
        ],
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
                    Row(
                      children: [
                        AiIdentityIcon(
                          providerId: original.id,
                          providerName: name.text,
                          baseUrl: url.text,
                          size: 40,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isPresetProvider(original.id)
                                ? l.v2ProviderPresetHelp
                                : l.v2ProviderCustom,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      key: const Key('provider_name'),
                      controller: name,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: l.v2Name),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.v2ProviderEnabled),
                      subtitle: Text(l.v2ProviderEnabledHelp),
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
                      onChanged: (v) => setState(() {
                        protocol = v!;
                        testResult = null;
                      }),
                    ),
                    TextField(
                      key: const Key('provider_url'),
                      controller: url,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l.v2BaseUrl,
                        helperText: l.v2BaseUrlHelp,
                      ),
                    ),
                    TextField(
                      key: const Key('provider_key'),
                      controller: keyInput,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: l.v2ApiKey,
                        helperText: l.v2KeyHelp,
                      ),
                    ),
                    if (original.secretRef != null)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l.v2ClearKey),
                        value: clearKey,
                        onChanged: (v) => setState(() {
                          clearKey = v!;
                          testResult = null;
                        }),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.wifi_tethering_rounded, size: 20),
                      onPressed: busy
                          ? null
                          : () => act(() async {
                              setState(() => testResult = null);
                              await p.testConnection(
                                draft,
                                keyInput.text,
                                models.firstOrNull ?? '',
                                clearKey: clearKey,
                                cancelToken: request,
                              );
                              if (mounted) {
                                setState(() => testResult = l.v2TestPassed);
                              }
                            }),
                      label: Text(l.v2TestConnection),
                    ),
                    if (testResult != null)
                      Text(testResult!, style: theme.textTheme.bodySmall),
                  ],
                ),
                Text(l.v2DraftHelp, style: theme.textTheme.bodySmall),
              ],
            ),
            _modelList(context),
          ],
        ),
      ),
    );
  }

  Widget _modelList(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final query = modelSearch.text.trim().toLowerCase();
    final visible = models
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
                Text(
                  l.v2ProviderModelCount(models.length),
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  l.v2ModelCapabilitiesHelp,
                  style: theme.textTheme.bodySmall,
                ),
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
                      onPressed: busy ? null : addManualModel,
                      icon: const Icon(Icons.add, size: 20),
                      label: Text(l.v2AddModel),
                    ),
                    OutlinedButton.icon(
                      key: const Key('provider_fetch_models'),
                      onPressed: busy ? null : fetchModels,
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
                final value = capabilities[id] ?? const ModelCapabilities();
                return Card(
                  child: ListTile(
                    key: ValueKey('provider_model_$id'),
                    leading: AiIdentityIcon(
                      model: id,
                      providerId: original.id,
                      providerName: name.text,
                      baseUrl: url.text,
                    ),
                    title: Text(id),
                    subtitle: Text(modelCapabilityLabel(context, value)),
                    onTap: () => editCapabilities(id),
                    trailing: IconButton(
                      tooltip: l.commonDelete,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => removeModel(id),
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
