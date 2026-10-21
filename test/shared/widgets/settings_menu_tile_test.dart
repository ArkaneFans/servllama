import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/shared/widgets/settings_menu_tile.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

void main() {
  testWidgets('grouped tile height grows with a multi-line subtitle', (
    tester,
  ) async {
    final subtitle = List.filled(12, 'Dynamic subtitle content').join(' ');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 260,
                child: SettingsSection.grouped(
                  title: 'Section',
                  children: [
                    SettingsMenuTile(
                      key: const Key('dynamic_tile'),
                      icon: Icons.info_outline_rounded,
                      title: 'Title',
                      subtitle: subtitle,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('dynamic_tile'))).height,
      greaterThan(76),
    );
  });
}
