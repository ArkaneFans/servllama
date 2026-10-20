import 'package:servllama/shared/widgets/app_message.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/features/speech/pages/speech_page.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

class ChatSpeechButton extends StatelessWidget {
  const ChatSpeechButton({super.key});
  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpeechJobService?>();
    if (service == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: context.l10n.v2TranscribeToChat,
      style: IconButton.styleFrom(minimumSize: const Size(48,48), padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
      icon: const Icon(Icons.mic_none),
      onPressed: !service.ready
          ? null
          : () => runUiAction(context, () async {
              final chat = context.read<ChatProvider>();
              final result = await Navigator.push<SpeechJob>(
                context,
                MaterialPageRoute(
                  builder: (_) => SpeechPage(
                    forChat: true,
                    conversationId: chat.draftKey,
                    draftAtEnqueue: chat.currentDraft,
                  ),
                ),
              );
              if (result != null && context.mounted) {
                await insertTranscript(context, result);
              }
            }),
    );
  }
}

Future<void> insertTranscript(BuildContext context, SpeechJob job) async {
  final chat = context.read<ChatProvider>(), l = context.l10n;
  String key = job.snapshot['conversationId'] as String? ?? chat.draftKey;
  final missing = !chat.hasDraftDestination(key);
  if (missing) key = chat.newDraftKey;
  final newDrafts = chat.newConversationDrafts;
  var reviewedDraft = chat.draftFor(key);
  final choice = await showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, change) => AlertDialog(
        title: Text(l.v2InsertTranscript),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (missing) Text(l.v2OriginalChatMissing),
              DropdownButtonFormField<String>(
                initialValue: key,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.v2TranscriptTarget),
                items: [
                  ...newDrafts.entries.map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value.isEmpty
                            ? l.chatNewSession
                            : l.v2AssistantDraft(entry.value),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  ...chat.sessions.map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.title, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    change(() {
                      key = value;
                      reviewedDraft = chat.draftFor(key);
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                chat.draftFor(key),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(l.v2NoAutomaticAudioUpload),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'replace'),
            child: Text(l.v2ReplaceDraft),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'append'),
            child: Text(l.v2AppendDraft),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  if (!chat.hasDraftDestination(key)) {
    throw StateError(l.v2OriginalChatMissing);
  }
  final previous = chat.draftFor(key);
  if (choice == 'replace' && previous != reviewedDraft) {
    throw StateError(l.v2DraftChanged);
  }
  chat.updateDraft(
    choice == 'replace' || previous.isEmpty
        ? job.text
        : '$previous\n${job.text}',
    key: key,
  );
  await chat.flushDrafts();
  if (!context.mounted) return;
  AppMessage.show(context, l.v2TranscriptInserted);
}
