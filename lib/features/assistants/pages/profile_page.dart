import 'package:servllama/shared/widgets/settings_section.dart';
import 'package:servllama/shared/widgets/form_list_view.dart';
import 'package:servllama/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/widgets/avatar_editor.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final p = context.read<AssistantProvider>().profile;
  late final name = TextEditingController(text: p.name),
      description = TextEditingController(text: p.description);
  late String avatar = p.avatar;
  bool avatarBusy = false, saving = false;
  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      appBar: AppBar(
        title: Text(l.v2Profile),
        actions: [
          TextButton(
            onPressed: avatarBusy || saving
                ? null
                : () => runUiAction(context, () async {
                    setState(() => saving = true);
                    try {
                      await context.read<AssistantProvider>().saveProfile(
                        UserProfile(
                          name: name.text.trim(),
                          avatar: avatar,
                          description: description.text,
                        ),
                      );
                      if (context.mounted) Navigator.pop(context);
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  }),
            child: Text(l.commonSave),
          ),
        ],
      ),
      body: FormListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          SettingsSection.form(
            title: l.v2IdentitySettings,
            children: [
              AvatarEditor(
                value: avatar,
                name: name.text,
                centered: true,
                enabled: !saving,
                onChanged: (value) => setState(() => avatar = value),
                onBusyChanged: (value) => setState(() => avatarBusy = value),
              ),
              TextField(
                controller: name,
                onChanged: (_) => setState(() {}),
                key: const Key('profile_name'),
                decoration: InputDecoration(labelText: l.v2UserName),
              ),
            ],
          ),
          SettingsSection.form(
            title: l.v2ProfileDescription,
            subtitle: l.v2ProfileHelp,
            children: [
              TextField(
                key: const Key('profile_description'),
                controller: description,
                minLines: 4,
                maxLines: 12,
                decoration: InputDecoration(
                  hintText: l.v2ProfileDescriptionHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
