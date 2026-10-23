import 'package:flutter/material.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/ai_identity_icon.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

class ProviderModelValue {
  const ProviderModelValue({
    required this.id,
    required this.name,
    required this.capabilities,
  });

  final String id, name;
  final ModelCapabilities capabilities;
}

class ProviderModelSheet extends StatefulWidget {
  const ProviderModelSheet({
    super.key,
    required this.existing,
    this.modelId,
    this.modelName = '',
    this.capabilities = ModelCapabilities.textOnly,
  });

  final Set<String> existing;
  final String? modelId;
  final String modelName;
  final ModelCapabilities capabilities;

  bool get isNew => modelId == null;

  @override
  State<ProviderModelSheet> createState() => _ProviderModelSheetState();
}

class _ProviderModelSheetState extends State<ProviderModelSheet> {
  final form = GlobalKey<FormState>();
  late final id = TextEditingController(text: widget.modelId);
  late final name = TextEditingController(text: widget.modelName);
  late bool images = widget.capabilities.supportsImages;
  late bool tools = widget.capabilities.supportsTools;
  bool nameEdited = false;

  @override
  void dispose() {
    id.dispose();
    name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(form.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      ProviderModelValue(
        id: id.text.trim(),
        name: name.text.trim(),
        capabilities: ModelCapabilities(
          supportsImages: images,
          supportsTools: tools,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final value = id.text.trim();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
              child: Row(
                children: [
                  AiIdentityIcon(model: value.isEmpty ? null : value, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.isNew ? l.v2AddModel : l.v2EditModel,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('provider_model_close'),
                    tooltip: l.commonCancel,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Form(
                key: form,
                child: ListView(
                  shrinkWrap: true,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    SettingsSection.form(
                      children: [
                        TextFormField(
                          key: const Key('provider_model_id'),
                          controller: id,
                          readOnly: !widget.isNew,
                          enableInteractiveSelection: widget.isNew,
                          autofocus: widget.isNew,
                          style: widget.isNew
                              ? null
                              : TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: .6,
                                  ),
                                ),
                          maxLength: 512,
                          textInputAction: TextInputAction.next,
                          onChanged: widget.isNew
                              ? (value) {
                                  if (!nameEdited) name.text = value;
                                  setState(() {});
                                }
                              : null,
                          decoration: InputDecoration(
                            labelText: l.v2ModelId,
                            counterText: '',
                          ),
                          validator: (raw) {
                            if (!widget.isNew) return null;
                            final value = raw?.trim() ?? '';
                            if (value.isEmpty) return l.v2ModelIdRequired;
                            if (widget.existing.contains(value)) {
                              return l.v2ModelAlreadyAdded;
                            }
                            return null;
                          },
                        ),
                        TextField(
                          key: const Key('provider_model_name'),
                          controller: name,
                          maxLength: 120,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            if (!nameEdited) {
                              setState(() => nameEdited = true);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: l.modelSettingsNameLabel,
                            counterText: '',
                          ),
                          onSubmitted: (_) => _submit(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SettingsSection.form(
                      title: l.v2ModelCapabilities,
                      children: [
                        SwitchListTile(
                          key: const Key('model_images'),
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.image_outlined),
                          title: Text(l.v2Images),
                          value: images,
                          onChanged: (value) => setState(() => images = value),
                        ),
                        SwitchListTile(
                          key: const Key('model_tools'),
                          contentPadding: EdgeInsets.zero,
                          secondary: const Icon(Icons.build_outlined),
                          title: Text(l.v2Tools),
                          value: tools,
                          onChanged: (value) => setState(() => tools = value),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: FilledButton.icon(
                key: Key(
                  widget.isNew
                      ? 'provider_model_add_button'
                      : 'provider_model_save_button',
                ),
                onPressed: _submit,
                icon: Icon(
                  widget.isNew ? Icons.add_rounded : Icons.save_outlined,
                ),
                label: Text(widget.isNew ? l.v2AddModelAction : l.commonSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String modelCapabilityLabel(BuildContext context, ModelCapabilities value) {
  final l = context.l10n;
  return [
    l.v2ModelText,
    if (value.supportsImages) l.v2ModelImages,
    if (value.supportsTools) l.v2ModelTools,
  ].join(' · ');
}
