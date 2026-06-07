import 'dart:io';

import 'package:flutter/material.dart';

class PendingImageStrip extends StatelessWidget {
  const PendingImageStrip({
    super.key,
    required this.paths,
    required this.onRemove,
  });

  final List<String> paths;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: paths.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _ImageThumbnail(
            path: paths[index],
            onRemove: () => onRemove(index),
            onTap: () => _showImagePreview(context, paths[index]),
          );
        },
      ),
    );
  }
}

class MessageImageStrip extends StatelessWidget {
  const MessageImageStrip({super.key, required this.imageFilePaths});

  final List<String> imageFilePaths;

  @override
  Widget build(BuildContext context) {
    if (imageFilePaths.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: imageFilePaths.map((path) {
          return _ImageThumbnail(
            path: path,
            size: 80,
            borderRadius: 14,
            onTap: () => _showImagePreview(context, path),
          );
        }).toList(),
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    required this.path,
    this.onRemove,
    this.onTap,
    this.size = 64,
    this.borderRadius = 12,
  });

  final String path;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final thumbnail = Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: SizedBox(
            width: size,
            height: size,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.broken_image_outlined,
                  size: size * 0.4,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
        if (onRemove != null)
          Positioned(
            right: -4,
            top: -4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorScheme.surface, width: 1.5),
                ),
                child: Icon(Icons.close, size: 12, color: colorScheme.onError),
              ),
            ),
          ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: thumbnail);
    }
    return thumbnail;
  }
}

void _showImagePreview(BuildContext context, String path) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '',
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) {
      return _ImagePreviewOverlay(path: path);
    },
  );
}

class _ImagePreviewOverlay extends StatelessWidget {
  const _ImagePreviewOverlay({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.black87),
            ),
          ),
          Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: GestureDetector(
                onTap: () {},
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }
}
