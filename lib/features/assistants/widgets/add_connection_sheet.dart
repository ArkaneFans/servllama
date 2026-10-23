import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/utils/new_id.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

/// Bottom sheet that creates a provider connection from its basic fields.
///
/// Only identity and connection essentials are collected here — models and
/// capabilities are configured later in the full editor. The add action is a
/// fixed button below the scrollable form so it stays reachable with the
/// keyboard open.
class AddConnectionSheet extends StatefulWidget {
  const AddConnectionSheet({super.key});

  @override
  State<AddConnectionSheet> createState() => _AddConnectionSheetState();
}

class _AddConnectionSheetState extends State<AddConnectionSheet> {
  static const _defaultApiPath = '/chat/completions';
  static const _defaultBaseUrls = {
    AiProtocol.openai: 'https://api.openai.com/v1',
    AiProtocol.anthropic: 'https://api.anthropic.com/v1',
    AiProtocol.gemini: 'https://generativelanguage.googleapis.com/v1beta',
  };

  final name = TextEditingController();
  final url = TextEditingController(text: _defaultBaseUrls[AiProtocol.openai]);
  final Map<AiProtocol, String> _baseUrlsByProtocol = {..._defaultBaseUrls};
  final apiPath = TextEditingController(text: _defaultApiPath);
  final keyInput = TextEditingController();
  bool enabled = true;
  AiProtocol protocol = AiProtocol.openai;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    apiPath.dispose();
    keyInput.dispose();
    super.dispose();
  }

  AiConnection get _draft {
    final trimmedPath = apiPath.text.trim();
    return AiConnection(
      id: newId(),
      name: name.text.trim(),
      protocol: protocol,
      baseUrl: url.text.trim(),
      apiPath: protocol == AiProtocol.openai && trimmedPath.isNotEmpty
          ? trimmedPath
          : null,
      enabled: enabled,
    );
  }

  Future<void> _add() async {
    if (busy) return;
    final navigator = Navigator.of(context);
    setState(() => busy = true);
    await runUiAction(context, () async {
      final connection = _draft;
      connection.validate();
      await context.read<AssistantProvider>().saveConnection(
        connection,
        key: keyInput.text,
      );
      if (mounted) navigator.pop();
    });
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Text(
                l.v2AddProvider,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  SettingsSection.form(
                    title: l.v2ProviderIdentity,
                    children: [
                      TextField(
                        key: const Key('provider_name'),
                        controller: name,
                        onChanged: (_) => setState(() {}),
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
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
                  const SizedBox(height: 16),
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
                        onChanged: (v) {
                          if (v == null) return;
                          _baseUrlsByProtocol[protocol] = url.text;
                          setState(() {
                            protocol = v;
                            url.text = _baseUrlsByProtocol[v] ?? '';
                          });
                        },
                      ),
                      TextField(
                        key: const Key('provider_url'),
                        controller: url,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
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
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(labelText: l.v2ApiKey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: FilledButton.icon(
                key: const Key('provider_add_button'),
                onPressed: busy ? null : _add,
                icon: const Icon(Icons.add_rounded),
                label: Text(l.v2Add),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
