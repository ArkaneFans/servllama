import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      builder: (_) => const _AssistantPickerSheet(),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Tooltip(
          message: l.v2SwitchAssistantNewChat,
          child: ListTile(
            key: const Key('drawer_assistant_selector'),
            enabled: enabled,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            minLeadingWidth: 32,
            horizontalTitleGap: 10,
            leading: IdentityAvatar(
              value: assistant?.avatar ?? '',
              name: assistant?.name ?? '',
              size: 32,
              fallbackIcon: Icons.smart_toy_outlined,
            ),
            title: Text(
              assistant?.name ?? l.v2UnassignedAssistant,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            trailing: const Icon(Icons.unfold_more_rounded, size: 22),
            onTap: enabled ? () => _showPicker(context, chat) : null,
          ),
        ),
      ),
    );
  }
}

class _AssistantPickerSheet extends StatelessWidget {
  const _AssistantPickerSheet();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AssistantProvider>();
    final chat = context.watch<ChatProvider>();
    final colors = Theme.of(context).colorScheme;
    final enabled = chat.canManageSessions && p.loaded && p.error == null;
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
                context.l10n.v2AssistantManagement,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 8),
                  itemCount: p.assistants.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final assistant = p.assistants[index];
                    final selected = assistant.id == chat.currentAssistant?.id;
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
                          key: Key('assistant_picker_item_${assistant.id}'),
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
                          trailing: selected
                              ? const Icon(Icons.check_rounded)
                              : null,
                          onTap: enabled
                              ? () => Navigator.of(context).pop(assistant.id)
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
