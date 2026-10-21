import 'package:flutter/material.dart';

/// A vertical list of setting tiles separated by the app's standard divider,
/// with the same per-tile vertical padding used across the settings page and
/// server config page.
///
/// Extracted from the duplicated private `_SectionItems` so the download
/// section's tiles line up exactly with the "General"/"Chat"/"About" groups.
class SettingsTileList extends StatelessWidget {
  const SettingsTileList({super.key, required this.children}) : grouped = false;

  const SettingsTileList.grouped({super.key, required this.children})
    : grouped = true;

  final List<Widget> children;
  final bool grouped;

  static const _groupedInset = 16.0;
  static const _groupedVerticalInset = 8.0;
  static const _groupedMinTileHeight = 76.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (grouped)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _groupedInset),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: _groupedMinTileHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: _groupedVerticalInset,
                  ),
                  child: children[index],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: children[index],
            ),
          if (index != children.length - 1)
            Divider(
              height: 1,
              indent: grouped ? _groupedInset : 0,
              endIndent: grouped ? _groupedInset : 0,
            ),
        ],
      ],
    );
  }
}
