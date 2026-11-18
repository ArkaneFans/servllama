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
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
      ),
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
                    conversationId: chat.inputContextKey,
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
  final key = chat.inputContextKey;
  final reviewedInput = chat.inputText;
  final original = job.snapshot['conversationId'] as String?;
  final choice = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l.v2InsertTranscript),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (original != null && original != key)
              Text(l.v2TranscriptContextChanged),
            Text(chat.selectedSession?.title ?? l.chatNewSession),
            const SizedBox(height: 8),
            Text(reviewedInput, maxLines: 4, overflow: TextOverflow.ellipsis),
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
          child: Text(l.v2ReplaceInput),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, 'append'),
          child: Text(l.v2AppendInput),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  if (chat.inputContextKey != key) {
    throw StateError(l.v2InputChanged);
  }
  final previous = chat.inputText;
  if (choice == 'replace' && previous != reviewedInput) {
    throw StateError(l.v2InputChanged);
  }
  chat.updateInputText(
    choice == 'replace' || previous.isEmpty
        ? job.text
        : '$previous\n${job.text}',
  );
  if (!context.mounted) return;
  AppMessage.show(context, l.v2TranscriptInserted);
}
