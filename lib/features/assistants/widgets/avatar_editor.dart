import 'package:flutter/material.dart';
import 'package:servllama/features/assistants/models/avatar_data.dart';
import 'package:servllama/features/assistants/services/avatar_image_service.dart';
import 'package:servllama/features/assistants/widgets/identity_avatar.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';

class AvatarEditor extends StatefulWidget {
  const AvatarEditor({
    super.key,
    required this.value,
    required this.name,
    required this.onChanged,
    required this.onBusyChanged,
    this.enabled = true,
    this.centered = false,
    this.service,
  });
  final String value, name;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onBusyChanged;
  final bool enabled, centered;
  final AvatarImageService? service;

  @override
  State<AvatarEditor> createState() => _AvatarEditorState();
}

class _AvatarEditorState extends State<AvatarEditor> {
  bool busy = false;

  Future<void> _pickImage() async {
    setState(() => busy = true);
    widget.onBusyChanged(true);
    try {
      await runUiAction(context, () async {
        try {
          final value = await (widget.service ?? AvatarImageService()).pick();
          if (mounted && value != null) widget.onChanged(value);
        } on AvatarImageException catch (error) {
          if (!mounted) return;
          throw StateError(
            error.reason == AvatarImageFailure.tooLarge
                ? context.l10n.v2AvatarImageTooLarge
                : context.l10n.v2AvatarInvalidImage,
          );
        }
      });
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusyChanged(false);
      }
    }
  }

  Future<void> _pickEmoji() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _EmojiDialog(value: widget.value),
    );
    if (mounted && value != null) widget.onChanged(value);
  }

  Future<void> _showMenu() async {
    final l = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('avatar_pick_image'),
              leading: const Icon(Icons.image_outlined),
              title: Text(l.v2AvatarImage),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              key: const Key('avatar_pick_emoji'),
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: Text(l.v2AvatarEmoji),
              onTap: () => Navigator.pop(context, 'emoji'),
            ),
            ListTile(
              key: const Key('avatar_reset'),
              leading: const Icon(Icons.restore),
              title: Text(l.v2AvatarReset),
              enabled: widget.value.isNotEmpty,
              onTap: () => Navigator.pop(context, 'reset'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'image':
        await _pickImage();
      case 'emoji':
        await _pickEmoji();
      case 'reset':
        widget.onChanged('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final enabled = widget.enabled && !busy;
    if (widget.centered) {
      return Center(
        child: Tooltip(
          message: l.v2AvatarHelp,
          child: InkWell(
            key: const Key('avatar_menu'),
            customBorder: const CircleBorder(),
            onTap: enabled ? _showMenu : null,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: IdentityAvatar(
                    value: widget.value,
                    name: widget.name,
                    size: 80,
                  ),
                ),
                if (busy)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (enabled)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: ExcludeSemantics(
                      child: DecoratedBox(
                        key: const Key('avatar_edit_badge'),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerLowest,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IdentityAvatar(value: widget.value, name: widget.name, size: 56),
              const SizedBox(width: 16),
              Expanded(child: Text(l.v2AvatarHelp)),
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('avatar_pick_image'),
                onPressed: enabled ? _pickImage : null,
                icon: const Icon(Icons.image_outlined),
                label: Text(l.v2AvatarImage),
              ),
              OutlinedButton.icon(
                key: const ValueKey('avatar_pick_emoji'),
                onPressed: enabled ? _pickEmoji : null,
                icon: const Icon(Icons.emoji_emotions_outlined),
                label: Text(l.v2AvatarEmoji),
              ),
              TextButton(
                onPressed: enabled && widget.value.isNotEmpty
                    ? () => widget.onChanged('')
                    : null,
                child: Text(l.v2AvatarReset),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmojiDialog extends StatefulWidget {
  const _EmojiDialog({required this.value});
  final String value;
  @override
  State<_EmojiDialog> createState() => _EmojiDialogState();
}

class _EmojiDialogState extends State<_EmojiDialog> {
  late final controller = TextEditingController(
    text: AvatarData.isImage(widget.value) || widget.value.isEmpty
        ? ''
        : widget.value.characters.first,
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.v2AvatarEmojiTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              children: [
                for (final emoji in const [
                  '🙂',
                  '🧑',
                  '🤖',
                  '🧠',
                  '📚',
                  '⚡',
                  '🌿',
                  '🎯',
                  '🦙',
                ])
                  TextButton(
                    onPressed: () => Navigator.pop(context, emoji),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
              ],
            ),
            TextField(
              key: const ValueKey('avatar_emoji_input'),
              controller: controller,
              maxLength: 1,
              decoration: InputDecoration(labelText: l.v2AvatarEmojiHint),
              onChanged: (_) => setState(() {}),
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
          onPressed: controller.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, controller.text.trim()),
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
