import 'package:flutter/material.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/l10n/l10n.dart';

enum ChatMessageAction { copy, edit, regenerate, delete }

class ChatMessageActionSheet extends StatelessWidget {
  const ChatMessageActionSheet({
    super.key,
    required this.message,
    required this.canRegenerate,
  });

  final ChatMessageRecord message;
  final bool canRegenerate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: Key('chat_message_action_copy_${message.id}'),
              leading: const Icon(Icons.content_copy_outlined),
              title: Text(l10n.chatCopyMessage),
              onTap: () => Navigator.of(context).pop(ChatMessageAction.copy),
            ),
            ListTile(
              key: Key('chat_message_action_edit_${message.id}'),
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.chatEditMessage),
              onTap: () => Navigator.of(context).pop(ChatMessageAction.edit),
            ),
            ListTile(
              key: Key('chat_message_action_regenerate_${message.id}'),
              leading: const Icon(Icons.refresh_rounded),
              title: Text(l10n.chatRegenerateMessage),
              enabled: canRegenerate,
              onTap: canRegenerate
                  ? () =>
                        Navigator.of(context).pop(ChatMessageAction.regenerate)
                  : null,
            ),
            ListTile(
              key: Key('chat_message_action_delete_${message.id}'),
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l10n.commonDelete),
              onTap: () => Navigator.of(context).pop(ChatMessageAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String?> showEditMessageSheet({
  required BuildContext context,
  required String initialValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _EditMessageSheet(initialValue: initialValue),
  );
}

class _EditMessageSheet extends StatefulWidget {
  const _EditMessageSheet({required this.initialValue});

  final String initialValue;

  @override
  State<_EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends State<_EditMessageSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 20),
      child: StatefulBuilder(
        builder: (context, setState) {
          final canSave = _controller.text.trim().isNotEmpty;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chatEditMessageTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('chat_message_edit_field'),
                controller: _controller,
                autofocus: true,
                minLines: 4,
                maxLines: 10,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: l10n.chatEditMessageHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('chat_message_edit_save_button'),
                    onPressed: canSave
                        ? () =>
                              Navigator.of(context).pop(_controller.text.trim())
                        : null,
                    child: Text(l10n.commonSave),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
