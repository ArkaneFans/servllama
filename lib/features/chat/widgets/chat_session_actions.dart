import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';

enum ChatSessionAction { rename, assistant, delete }

class ChatSessionActions {
  const ChatSessionActions._();

  static Future<void> showSessionActions({
    required BuildContext context,
    required BuildContext presentationContext,
    required ChatSessionRecord session,
  }) async {
    final provider = context.read<ChatProvider>();
    if (!provider.canManageSessions) {
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!presentationContext.mounted) {
      return;
    }

    final action = await showModalBottomSheet<ChatSessionAction>(
      context: presentationContext,
      builder: (context) {
        final l10n = context.l10n;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(l10n.commonRename),
                onTap: () =>
                    Navigator.of(context).pop(ChatSessionAction.rename),
              ),
              if (provider.hasAssistantContext)
                ListTile(
                  leading: const Icon(Icons.manage_accounts_outlined),
                  title: Text(l10n.v2ChangeConversationAssistant),
                  onTap: () =>
                      Navigator.of(context).pop(ChatSessionAction.assistant),
                ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.commonDelete),
                onTap: () =>
                    Navigator.of(context).pop(ChatSessionAction.delete),
              ),
            ],
          ),
        );
      },
    );

    if (action == null || !presentationContext.mounted) {
      return;
    }

    switch (action) {
      case ChatSessionAction.assistant:
        await changeAssistant(
          provider: provider,
          presentationContext: presentationContext,
          session: session,
        );
      case ChatSessionAction.rename:
        await renameSession(
          provider: provider,
          presentationContext: presentationContext,
          session: session,
        );
      case ChatSessionAction.delete:
        await deleteSession(
          provider: provider,
          presentationContext: presentationContext,
          session: session,
        );
    }
  }

  static Future<void> changeAssistant({
    required ChatProvider provider,
    required BuildContext presentationContext,
    required ChatSessionRecord session,
  }) async {
    final assistants = presentationContext.read<AssistantProvider>().assistants;
    String? selected = assistants.any((a) => a.id == session.assistantId)
        ? session.assistantId
        : null;
    final result = await showDialog<String>(
      context: presentationContext,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final l = context.l10n;
          return AlertDialog(
            title: Text(l.v2ChangeConversationAssistant),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l.v2ChangeConversationAssistantHelp),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.v2FirstAssistants),
                    items: assistants
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (id) => update(() => selected = id),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.commonCancel),
              ),
              FilledButton(
                onPressed: selected == null || selected == session.assistantId
                    ? null
                    : () => Navigator.pop(context, selected),
                child: Text(l.commonSave),
              ),
            ],
          );
        },
      ),
    );
    if (result != null) await provider.reassignAssistant(session.id, result);
  }

  static Future<void> renameSession({
    required ChatProvider provider,
    required BuildContext presentationContext,
    required ChatSessionRecord session,
  }) async {
    var draftTitle = session.title;
    final result = await showDialog<String>(
      context: presentationContext,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.chatRenameSessionTitle),
          content: TextFormField(
            initialValue: session.title,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.chatRenameSessionHint,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              draftTitle = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(draftTitle),
              child: Text(l10n.commonSave),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }
    await provider.renameSession(session.id, result);
  }

  static Future<void> deleteSession({
    required ChatProvider provider,
    required BuildContext presentationContext,
    required ChatSessionRecord session,
  }) async {
    final confirmed = await showDialog<bool>(
      context: presentationContext,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.chatDeleteSessionTitle),
          content: Text(l10n.chatDeleteSessionConfirm(session.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }
    await provider.deleteSession(session.id);
  }
}
