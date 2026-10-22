import 'package:flutter/material.dart';

/// A vertical list of setting tiles separated by the app's standard divider,
/// with the same horizontal inset used across grouped settings pages.
///
/// Extracted from the duplicated private `_SectionItems` so the download
/// section's tiles line up exactly with the "General"/"Chat"/"About" groups.
///
/// Lets [SettingsMenuTile] use grouped-list sizing while ungrouped server
/// settings keep their existing spacing.
class SettingsTileGroupScope extends InheritedWidget {
  const SettingsTileGroupScope({super.key, required super.child});

  @override
  bool updateShouldNotify(SettingsTileGroupScope oldWidget) => false;
}

class SettingsTileList extends StatelessWidget {
  const SettingsTileList({super.key, required this.children}) : grouped = false;

  const SettingsTileList.grouped({super.key, required this.children})
    : grouped = true;

  final List<Widget> children;
  final bool grouped;

  static const _groupedInset = 16.0;

  @override
  Widget build(BuildContext context) {
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (grouped)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _groupedInset),
              child: children[index],
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
    return grouped ? SettingsTileGroupScope(child: list) : list;
  }
}
