import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/app/app_theme.dart';
import 'package:servllama/shared/widgets/app_empty_state.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('uses shared typography and spacing in $brightness', (
      tester,
    ) async {
      final theme = brightness == Brightness.light
          ? AppTheme.light()
          : AppTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: AppEmptyState(
              icon: Icon(Icons.memory_outlined),
              title: 'No models yet',
              description: 'Tap + to add a model',
            ),
          ),
        ),
      );

      final title = find.text('No models yet');
      final description = find.text('Tap + to add a model');
      final icon = find.byIcon(Icons.memory_outlined);
      final resolvedTheme = Theme.of(tester.element(title));
      expect(
        tester.widget<Text>(title).style,
        resolvedTheme.textTheme.titleMedium,
      );
      expect(
        tester.widget<Text>(description).style,
        resolvedTheme.textTheme.bodyMedium?.copyWith(
          color: resolvedTheme.colorScheme.onSurfaceVariant,
        ),
      );
      expect(tester.widget<Text>(title).textAlign, TextAlign.center);
      expect(tester.widget<Text>(description).textAlign, TextAlign.center);
      expect(tester.getSize(icon), const Size(40, 40));
      expect(
        IconTheme.of(tester.element(icon)).color,
        theme.colorScheme.outline,
      );
      expect(tester.getTopLeft(title).dy - tester.getBottomLeft(icon).dy, 16);
      expect(
        tester.getTopLeft(description).dy - tester.getBottomLeft(title).dy,
        8,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('remains scrollable in a short viewport with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icon(Icons.memory_outlined),
                  title: 'No models yet',
                  description: 'Tap + to add a model',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Tap + to add a model'));
    await tester.pumpAndSettle();
    expect(find.text('Tap + to add a model').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
