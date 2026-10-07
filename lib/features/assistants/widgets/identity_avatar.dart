import 'package:flutter/material.dart';
import 'package:servllama/features/assistants/models/avatar_data.dart';
import 'package:servllama/l10n/l10n.dart';

class IdentityAvatar extends StatefulWidget {
  const IdentityAvatar({
    super.key,
    required this.value,
    required this.name,
    this.size = 32,
    this.fallbackIcon = Icons.person_outline,
  });
  final String value, name;
  final double size;
  final IconData fallbackIcon;

  @override
  State<IdentityAvatar> createState() => _IdentityAvatarState();
}

class _IdentityAvatarState extends State<IdentityAvatar> {
  MemoryImage? _image;

  @override
  void initState() {
    super.initState();
    _readImage();
  }

  @override
  void didUpdateWidget(IdentityAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _readImage();
  }

  void _readImage() {
    _image = null;
    if (!AvatarData.isImage(widget.value)) return;
    try {
      _image = MemoryImage(AvatarData.imageBytes(widget.value));
    } on FormatException {
      // A damaged stored thumbnail must not prevent opening the conversation.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = AvatarData.isImage(widget.value) || widget.value.trim().isEmpty
        ? widget.name.trim()
        : widget.value.trim();
    final fallback = Center(
      child: text.isEmpty
          ? Icon(
              widget.fallbackIcon,
              size: widget.size * .55,
              color: colors.onSecondaryContainer,
            )
          : Text(
              text.characters.first,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontSize: widget.size * .48,
                fontWeight: FontWeight.w600,
                color: colors.onSecondaryContainer,
              ),
            ),
    );
    return Semantics(
      image: true,
      label: context.l10n.v2Avatar,
      child: ExcludeSemantics(
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: colors.secondaryContainer,
            shape: BoxShape.circle,
          ),
          clipBehavior: Clip.antiAlias,
          child: _image == null
              ? fallback
              : Image(
                  image: _image!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => fallback,
                ),
        ),
      ),
    );
  }
}
