import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/speech/models/speech_models.dart';
import 'package:servllama/features/speech/services/speech_job_service.dart';
import 'package:servllama/features/speech/widgets/speech_job_widgets.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:servllama/shared/widgets/async_action.dart';
import 'package:servllama/shared/widgets/form_list_view.dart';

class SpeechJobPage extends StatefulWidget {
  const SpeechJobPage({super.key, required this.id, this.canInsert = false});
  final String id;
  final bool canInsert;
  @override
  State<SpeechJobPage> createState() => _SpeechJobPageState();
}

class _SpeechJobPageState extends State<SpeechJobPage> {
  late String id = widget.id;
  bool deleting = false, retrying = false;
  @override
  Widget build(BuildContext context) {
    final service = context.watch<SpeechJobService>(), l = context.l10n;
    final job = service.job(id);
    return AppScaffold(
      appBar: AppBar(
        title: Text(l.v2TaskResult),
        actions: [
          if (job != null && !job.state.active)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l.commonDelete,
              onPressed: deleting || retrying
                  ? null
                  : () => runUiAction(context, () async {
                      setState(() => deleting = true);
                      try {
                        await service.deleteJob(id);
                        if (context.mounted) Navigator.pop(context);
                      } finally {
                        if (mounted) setState(() => deleting = false);
                      }
                    }),
            ),
        ],
      ),
      body: job == null
          ? Center(child: Text(l.v2NoSpeechJobs))
          : FormListView(
              children: [
                SpeechJobResult(
                  key: ValueKey(id),
                  id: id,
                  onRetry: (previous) async {
                    if (deleting || retrying) return;
                    setState(() => retrying = true);
                    try {
                      final next = await service.retry(previous);
                      if (mounted) setState(() => id = next.id);
                    } finally {
                      if (mounted) setState(() => retrying = false);
                    }
                  },
                  onInsert: widget.canInsert
                      ? (result) => Navigator.pop(context, result)
                      : null,
                ),
              ],
            ),
    );
  }
}
