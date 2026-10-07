import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/shared/widgets/async_action.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/widgets/chat_session_actions.dart';
import 'package:servllama/features/chat/widgets/chat_session_search_field.dart';
import 'package:servllama/l10n/l10n.dart';

class ChatHistoryPage extends StatelessWidget {
  const ChatHistoryPage({super.key, this.onSessionOpened});

  final VoidCallback? onSessionOpened;

  Future<void> _openSession(
    BuildContext context,
    ChatProvider provider,
    String sessionId,
  ) async {
    unawaited(provider.switchSession(sessionId));
    Navigator.of(context).pop();
    onSessionOpened?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    return AppScaffold(
      appBar: AppBar(title: Text(l10n.chatHistoryTitle)),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ChatSessionSearchField(
                key: Key('history_page_search_box'),
                fieldKey: Key('history_page_search_input'),
                autofocus: false,
              ),
              const SizedBox(height: 12),
              if (context.watch<AssistantProvider?>() != null)
                Text(l10n.v2AllAssistantHistory),
              Expanded(
                child: Consumer<ChatProvider>(
                  builder: (context, provider, _) {
                    final sessions = provider.filteredSessions;
                    final isQueryEmpty = provider.sessionQuery.trim().isEmpty;

                    if (provider.isLoading && provider.sessions.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.sessions.isEmpty) {
                      return Center(
                        child: Text(
                          l10n.chatSessionEmpty,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    if (sessions.isEmpty) {
                      return Center(
                        child: Text(
                          isQueryEmpty
                              ? l10n.chatSessionEmpty
                              : l10n.chatSessionNotFound,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final session = sessions[index];
                        return _HistorySessionCard(
                          session: session,
                          onTap: provider.canManageSessions
                              ? () =>
                                    _openSession(context, provider, session.id)
                              : null,
                          onRename: provider.canManageSessions
                              ? () => ChatSessionActions.renameSession(
                                  provider: provider,
                                  presentationContext: context,
                                  session: session,
                                )
                              : null,
                          onDelete: provider.canManageSessions
                              ? () => ChatSessionActions.deleteSession(
                                  provider: provider,
                                  presentationContext: context,
                                  session: session,
                                )
                              : null,
                        );
                      },
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

class _HistorySessionCard extends StatelessWidget {
  const _HistorySessionCard({
    required this.session,
    this.onTap,
    this.onRename,
    this.onDelete,
  });

  final ChatSessionRecord session;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final assistants = context.watch<AssistantProvider?>();
    final author = assistants?.assistants
        .where((a) => a.id == session.assistantId)
        .firstOrNull;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant.withAlpha(110)),
        ),
        child: InkWell(
          key: Key('history_session_item_${session.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (assistants != null)
                        Text(
                          author?.name ?? l10n.v2UnassignedAssistant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<_HistorySessionMenuAction>(
                  key: Key('history_session_menu_${session.id}'),
                  tooltip: l10n.chatMoreActions,
                  onSelected: (action) {
                    switch (action) {
                      case _HistorySessionMenuAction.assistant:
                        runUiAction(
                          context,
                          () => ChatSessionActions.changeAssistant(
                            provider: context.read<ChatProvider>(),
                            presentationContext: context,
                            session: session,
                          ),
                        );
                        break;
                      case _HistorySessionMenuAction.rename:
                        onRename?.call();
                        break;
                      case _HistorySessionMenuAction.delete:
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (assistants != null)
                      PopupMenuItem(
                        value: _HistorySessionMenuAction.assistant,
                        enabled: context.read<ChatProvider>().canManageSessions,
                        child: Text(l10n.v2ChangeConversationAssistant),
                      ),
                    PopupMenuItem(
                      value: _HistorySessionMenuAction.rename,
                      child: Text(l10n.commonRename),
                    ),
                    PopupMenuItem(
                      value: _HistorySessionMenuAction.delete,
                      child: Text(l10n.commonDelete),
                    ),
                  ],
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _HistorySessionMenuAction { rename, assistant, delete }
