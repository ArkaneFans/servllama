import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/l10n/l10n.dart';

class ChatSessionSearchField extends StatefulWidget {
  const ChatSessionSearchField({
    super.key,
    this.fieldKey,
    this.hintText,
    this.autofocus = false,
  });

  final Key? fieldKey;
  final String? hintText;
  final bool autofocus;

  @override
  State<ChatSessionSearchField> createState() => _ChatSessionSearchFieldState();
}

class _ChatSessionSearchFieldState extends State<ChatSessionSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final query = context.select(
      (ChatProvider provider) => provider.sessionQuery,
    );

    if (_controller.text != query) {
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    }

    return Container(
      key: widget.key,
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(56)),
      ),
      child: TextField(
        key: widget.fieldKey,
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: context.read<ChatProvider>().updateSessionQuery,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: widget.hintText ?? context.l10n.chatSearchHint,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 26),
        ),
      ),
    );
  }
}
