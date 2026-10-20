import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/widgets/identity_avatar.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

/// Selecting an assistant starts its draft and filters the sidebar history.
/// Moving an existing conversation remains an explicit conversation action.
class AssistantSelector extends StatelessWidget {
  const AssistantSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AssistantProvider?>();
    if (p == null) return const SizedBox.shrink();
    final chat = context.watch<ChatProvider>();
    final l = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Tooltip(
          message: l.v2SwitchAssistantNewChat,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              key: const Key('drawer_assistant_selector'),
              value: chat.currentAssistant?.id,
              isExpanded: true,
              borderRadius: BorderRadius.circular(18),
              menuMaxHeight: MediaQuery.sizeOf(context).height * .65,
              icon: const Icon(Icons.unfold_more_rounded, size: 22),
              hint: Text(l.v2UnassignedAssistant),
              items: p.assistants
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Row(
                        children: [
                          IdentityAvatar(
                            value: a.avatar,
                            name: a.name,
                            size: 32,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: !chat.canManageSessions || !p.loaded
                  ? null
                  : (id) =>
                        runUiAction(context, () => chat.selectAssistant(id!)),
            ),
          ),
        ),
      ),
    );
  }
}
