import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';

class SkillFilePage extends StatefulWidget {
  const SkillFilePage({super.key, required this.skill, required this.file});

  final SkillRecord skill;
  final SkillFileEntry file;

  @override
  State<SkillFilePage> createState() => _SkillFilePageState();
}

class _SkillFilePageState extends State<SkillFilePage> {
  String? text;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    try {
      final value = await context.read<AgentToolService>().readSkillText(
        widget.skill,
        relativePath: widget.file.relativePath,
      );
      if (mounted) setState(() => text = value);
    } catch (_) {
      if (mounted) setState(() => error = context.l10n.v2SkillFileReadFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: Text(widget.file.relativePath)),
      body: text != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: SelectableText(
                text!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.55,
                ),
              ),
            )
          : error != null
          ? Center(child: Text(error!))
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
