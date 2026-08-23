import 'package:flutter/material.dart';

/// A vertical list of setting tiles separated by the app's standard divider,
/// with the same per-tile vertical padding used across the settings page and
/// server config page.
///
/// Extracted from the duplicated private `_SectionItems` so the download
/// section's tiles line up exactly with the "General"/"Chat"/"About" groups.
class SettingsTileList extends StatelessWidget {
  const SettingsTileList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: children[index],
          ),
          if (index != children.length - 1)
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withAlpha(90),
            ),
        ],
      ],
    );
  }
}
