import 'package:servllama/shared/widgets/ai_identity_icon.dart';
import 'package:flutter/material.dart';
import 'package:servllama/l10n/l10n.dart';

class AddProviderModelDialog extends StatefulWidget {
  const AddProviderModelDialog({super.key, required this.existing});
  final Set<String> existing;
  @override
  State<AddProviderModelDialog> createState() => _AddProviderModelDialogState();
}

class _AddProviderModelDialogState extends State<AddProviderModelDialog> {
  final input = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.v2AddModel),
      content: Form(
        key: form,
        child: TextFormField(
          key: const Key('provider_manual_model'),
          controller: input,
          autofocus: true,
          maxLength: 512,
          decoration: InputDecoration(labelText: l.v2ModelId),
          validator: (value) => value == null || value.trim().isEmpty
              ? l.v2ModelIdRequired
              : widget.existing.contains(value.trim())
              ? l.v2ModelAlreadyAdded
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, input.text.trim());
            }
          },
          child: Text(l.v2Add),
        ),
      ],
    );
  }
}

/// Endpoint results are candidates, never a replacement for the saved list.
class ProviderModelPicker extends StatefulWidget {
  const ProviderModelPicker({
    super.key,
    required this.models,
    required this.existing,
  });
  final List<String> models;
  final Set<String> existing;

  @override
  State<ProviderModelPicker> createState() => _ProviderModelPickerState();
}

class _ProviderModelPickerState extends State<ProviderModelPicker> {
  final search = TextEditingController();
  final selected = <String>{};
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final query = search.text.trim().toLowerCase();
    final visible = widget.models
        .where((id) => id.toLowerCase().contains(query))
        .toList();
    final available = visible
        .where((id) => !widget.existing.contains(id))
        .toSet();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 560,
        height: MediaQuery.sizeOf(context).height * .75,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l.v2DiscoveredModels,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const Key('provider_model_search'),
                            controller: search,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: l.v2ModelSearch,
                            ),
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) =>
                                FocusManager.instance.primaryFocus?.unfocus(),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: available.isEmpty
                                  ? null
                                  : () => setState(() {
                                      if (selected.containsAll(available)) {
                                        selected.removeAll(available);
                                      } else {
                                        selected.addAll(available);
                                      }
                                    }),
                              child: Text(
                                selected.containsAll(available) &&
                                        available.isNotEmpty
                                    ? l.v2DeselectVisible
                                    : l.v2SelectVisible,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (visible.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(l.modelLibraryEmptySearchTitle),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final id = visible[index];
                          final exists = widget.existing.contains(id);
                          return CheckboxListTile(
                            key: ValueKey('provider_candidate_$id'),
                            secondary: AiIdentityIcon(model: id, size: 32),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              id,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: exists
                                ? Text(l.v2ModelAlreadyAdded)
                                : null,
                            value: exists || selected.contains(id),
                            onChanged: exists
                                ? null
                                : (value) => setState(() {
                                    if (value == true) {
                                      selected.add(id);
                                    } else {
                                      selected.remove(id);
                                    }
                                  }),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.commonCancel),
                  ),
                  FilledButton(
                    key: const Key('provider_add_selected'),
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(context, selected.toList()),
                    child: Text(l.v2AddSelectedModels(selected.length)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
