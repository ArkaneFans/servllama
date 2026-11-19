import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/assistants/pages/assistants_page.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/widgets/identity_avatar.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

/// Selecting an assistant starts a new chat and filters the sidebar history.
/// Moving an existing conversation remains an explicit conversation action.
class AssistantSelector extends StatelessWidget {
  const AssistantSelector({super.key});

  Future<void> _showPicker(BuildContext context, ChatProvider chat) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const _AssistantPickerSheet(),
      ),
    );
    if (id != null && context.mounted) {
      await runUiAction(context, () => chat.selectAssistant(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AssistantProvider?>();
    if (p == null) return const SizedBox.shrink();
    final chat = context.watch<ChatProvider>();
    final l = context.l10n;
    final assistant = chat.currentAssistant;
    final enabled = chat.canManageSessions && p.loaded && p.error == null;
    return Material(
      type: MaterialType.transparency,
      child: Tooltip(
        message: l.v2SwitchAssistantNewChat,
        child: ListTile(
          key: const Key('drawer_assistant_selector'),
          enabled: enabled,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding: EdgeInsets.zero,
          minLeadingWidth: 48,
          horizontalTitleGap: 12,
          leading: IdentityAvatar(
            value: assistant?.avatar ?? '',
            name: assistant?.name ?? '',
            size: 48,
            fallbackIcon: Icons.smart_toy_outlined,
          ),
          title: Text(
            assistant?.name ?? l.v2UnassignedAssistant,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          trailing: const SizedBox.square(
            dimension: 48,
            child: Center(child: Icon(Icons.unfold_more_rounded, size: 22)),
          ),
          onTap: enabled ? () => _showPicker(context, chat) : null,
        ),
      ),
    );
  }
}

class _AssistantPickerSheet extends StatefulWidget {
  const _AssistantPickerSheet();

  @override
  State<_AssistantPickerSheet> createState() => _AssistantPickerSheetState();
}

class _AssistantPickerSheetState extends State<_AssistantPickerSheet> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AssistantProvider>();
    final chat = context.watch<ChatProvider>();
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final enabled = chat.canManageSessions && p.loaded && p.error == null;
    final query = search.text.trim().toLowerCase();
    final visible = query.isEmpty
        ? p.assistants
        : p.assistants
              .where(
                (assistant) => assistant.name.toLowerCase().contains(query),
              )
              .toList();
    return FractionallySizedBox(
      heightFactor: .8,
      child: SafeArea(
        top: false,
        child: Padding(
          key: const Key('assistant_picker_sheet'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.v2AssistantManagement,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('assistant_picker_search'),
                controller: search,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  hintText: l.v2AssistantSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('assistant_picker_search_clear'),
                          tooltip: l.v2AssistantSearchClear,
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(search.clear),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Text(
                          l.v2AssistantNoResults,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final assistant = visible[index];
                          final selected =
                              assistant.id == chat.currentAssistant?.id;
                          return Semantics(
                            selected: selected,
                            child: Card(
                              margin: EdgeInsets.zero,
                              color: selected
                                  ? colors.primaryContainer
                                  : colors.surfaceContainerLow,
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: ListTile(
                                key: Key(
                                  'assistant_picker_item_${assistant.id}',
                                ),
                                enabled: enabled,
                                selected: selected,
                                selectedColor: colors.onPrimaryContainer,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                leading: IdentityAvatar(
                                  value: assistant.avatar,
                                  name: assistant.name,
                                  size: 40,
                                ),
                                title: Text(
                                  assistant.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  key: Key(
                                    'assistant_picker_edit_${assistant.id}',
                                  ),
                                  tooltip: l.v2AssistantEditor,
                                  color: selected
                                      ? colors.onPrimaryContainer
                                      : colors.onSurfaceVariant,
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: enabled
                                      ? () => Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => AssistantEditor(
                                              assistant: assistant,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                onTap: enabled
                                    ? () => Navigator.of(
                                        context,
                                      ).pop(assistant.id)
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
