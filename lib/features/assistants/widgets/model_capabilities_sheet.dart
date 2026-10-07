import 'package:flutter/material.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/ai_identity_icon.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

String modelCapabilityLabel(BuildContext context, ModelCapabilities value) {
  final l = context.l10n;
  return [
    l.v2ModelText,
    if (value.supportsImages) l.v2ModelImages,
    if (value.supportsTools) l.v2ModelTools,
  ].join(' · ');
}

class ModelCapabilitiesSheet extends StatefulWidget {
  const ModelCapabilitiesSheet({
    super.key,
    required this.model,
    required this.initial,
  });
  final String model;
  final ModelCapabilities initial;
  @override
  State<ModelCapabilitiesSheet> createState() => _ModelCapabilitiesSheetState();
}

class _ModelCapabilitiesSheetState extends State<ModelCapabilitiesSheet> {
  late bool images = widget.initial.supportsImages,
      tools = widget.initial.supportsTools;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 16,
          children: [
            Row(
              children: [
                AiIdentityIcon(model: widget.model),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.model,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('model_capabilities_close'),
                  tooltip: l.commonCancel,
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SettingsSection.form(
              title: l.v2ModelCapabilities,
              children: [
                SwitchListTile(
                  key: const Key('model_images'),
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.image_outlined),
                  title: Text(l.v2Images),
                  value: images,
                  onChanged: (v) => setState(() => images = v),
                ),
                SwitchListTile(
                  key: const Key('model_tools'),
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.build_outlined),
                  title: Text(l.v2Tools),
                  value: tools,
                  onChanged: (v) => setState(() => tools = v),
                ),
              ],
            ),
            Text(
              l.v2ModelCapabilitiesHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            FilledButton(
              key: const Key('model_capabilities_done'),
              onPressed: () => Navigator.pop(
                context,
                ModelCapabilities(supportsImages: images, supportsTools: tools),
              ),
              child: Text(l.commonDone),
            ),
          ],
        ),
      ),
    );
  }
}
