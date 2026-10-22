import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/shared/widgets/settings_menu_tile.dart';
import 'package:servllama/shared/widgets/settings_section.dart';

void main() {
  testWidgets('grouped tiles follow the three Material list heights', (
    tester,
  ) async {
    final multilineSubtitle = List.filled(
      4,
      'Dynamic subtitle content',
    ).join(' ');

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
                      key: const Key('one_line_tile'),
                      icon: Icons.info_outline_rounded,
                      title: 'One line',
                    ),
                    SettingsMenuTile(
                      key: const Key('two_line_tile'),
                      icon: Icons.info_outline_rounded,
                      title: 'Title',
                      subtitle: 'Short',
                      onTap: () {},
                    ),
                    SettingsMenuTile(
                      key: const Key('multiline_tile'),
                      icon: Icons.info_outline_rounded,
                      title: 'Title',
                      subtitle: multilineSubtitle,
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
      tester.getSize(find.byKey(const Key('one_line_tile'))).height,
      moreOrLessEquals(56),
    );
    expect(
      tester.getSize(find.byKey(const Key('two_line_tile'))).height,
      moreOrLessEquals(72),
    );
    expect(
      tester.getSize(find.byKey(const Key('multiline_tile'))).height,
      greaterThanOrEqualTo(88),
    );
  });
}
