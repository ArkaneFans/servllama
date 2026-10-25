import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../support/app_startup_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'unmounted snapshot preparation is single flight and precedes drafts',
    () async {
      final fixture = AppStartupFixture();
      addTearDown(fixture.dispose);
      final pending = Completer<void>();
      fixture.assistants.pending = pending;
      final first = fixture.startup.prepare();
      expect(identical(first, fixture.startup.prepare()), isTrue);
      expect(fixture.startup.ready, isFalse);
      expect(fixture.chat.draftLoads, 0);
      pending.complete();
      await first;
      expect(fixture.startup.ready, isTrue);
      expect(fixture.startup.error, isNull);
      expect(fixture.assistants.reconciliationModes, [false]);
      expect(fixture.downloads.transferModes, [false]);
      expect(fixture.chat.currentAssistantId, 'a');
      expect(fixture.chat.draftLoads, 1);
      expect(fixture.chat.historyLoads, 0);
      await fixture.startup.prepare();
      expect(fixture.chat.draftLoads, 1);
      expect(fixture.assistants.reconciliationModes, [false]);
    },
  );

  test(
    'pre-runApp failure is captured and an explicit retry reuses the scope',
    () async {
      final fixture = AppStartupFixture();
      addTearDown(fixture.dispose);
      fixture.assistants.fail = true;
      await expectLater(fixture.startup.prepare(), throwsStateError);
      expect(fixture.startup.ready, isFalse);
      expect(fixture.startup.error, isA<StateError>());
      expect(fixture.chat.draftLoads, 0);
      fixture.assistants.fail = false;
      await fixture.startup.prepare();
      expect(fixture.startup.ready, isTrue);
      expect(fixture.startup.error, isNull);
      expect(fixture.assistants.reconciliationModes, [false, false]);
      expect(fixture.chat.draftLoads, 1);
    },
  );
}
