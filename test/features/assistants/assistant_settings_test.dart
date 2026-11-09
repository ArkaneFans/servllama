import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/app/providers/app_locale_provider.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/services/app_l10n_service.dart';
import 'package:servllama/core/storage/app_prefs_keys.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/assistants/repositories/assistant_repository.dart';
import 'package:servllama/features/assistants/pages/assistants_page.dart';
import 'package:servllama/features/assistants/pages/profile_page.dart';
import 'package:servllama/features/assistants/widgets/identity_avatar.dart';
import 'package:servllama/features/agent/models/agent_records.dart';
import 'package:servllama/features/agent/repositories/agent_repository.dart';
import 'package:servllama/features/agent/services/agent_tool_service.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';
import 'package:servllama/l10n/generated/app_localizations.dart';

class _NoModels extends UnifiedModelRepository {
  @override
  Future<List<ModelAsset>> listLlmAssets() async => [];
}

class _MemoryPreferences extends KvStorage {
  final values = <String, String>{};
  @override
  Future<String?> getString(String key) async => values[key];
  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

class _PendingLocalePreferences extends _MemoryPreferences {
  final pending = Completer<String?>();
  int reads = 0;

  @override
  Future<String?> getString(String key) {
    if (key != AppPrefsKeys.localeMode) return super.getString(key);
    reads++;
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late AssistantRepository repository;
  late AssistantProvider provider;
  Locale? previousLocale;
  const a = Assistant(id: 'a', name: 'A');
  const b = Assistant(id: 'b', name: 'B');
  const connection = AiConnection(
    id: 'c',
    name: 'C',
    protocol: AiProtocol.openai,
    baseUrl: 'https://example.com/v1',
    models: ['model'],
  );
  setUp(() async {
    previousLocale = AppL10nService.instance.appLocale;
    db = AppDatabase.memory();
    repository = AssistantRepository(db, preferences: _MemoryPreferences());
    provider = AssistantProvider(repository: repository, models: _NoModels());
    await repository.saveAssistant(a);
    await repository.saveAssistant(b);
    await provider.load();
  });
  tearDown(() async {
    provider.dispose();
    await db.close();
    AppL10nService.instance.setLocale(previousLocale);
  });
  ChatRunConfig config(Assistant assistant) => ChatRunConfig(
    assistant: assistant,
    connection: connection,
    key: 'not-persisted',
    modelId: 'model',
    isLocal: false,
  );

  for (final (language, expected) in [
    ('zh', 'AI 助手'),
    ('en', 'AI Assistant'),
  ]) {
    test('first load persists one localized assistant ($language)', () async {
      AppL10nService.instance.setLocale(Locale(language));
      final freshDb = AppDatabase.memory();
      final freshRepository = AssistantRepository(
        freshDb,
        preferences: _MemoryPreferences(),
      );
      final freshProvider = AssistantProvider(
        repository: freshRepository,
        models: _NoModels(),
      );
      addTearDown(() async {
        freshProvider.dispose();
        await freshDb.close();
      });

      await freshProvider.ensureLoaded();
      final initial = freshProvider.assistants.single;
      expect(initial.name, expected);
      expect(freshProvider.activeId, initial.id);
      expect((await freshRepository.assistants()).single.name, expected);
      AppL10nService.instance.setLocale(Locale(language == 'zh' ? 'en' : 'zh'));
      await freshProvider.load();
      expect(freshProvider.assistants.single.id, initial.id);
      expect(freshProvider.active?.name, expected);
    });
  }

  test(
    'first-use seeding joins delayed locale restoration before saving',
    () async {
      final prefs = _PendingLocalePreferences();
      final locale = AppLocaleProvider(kvStorage: prefs);
      addTearDown(locale.dispose);
      AppL10nService.instance.setLocale(const Locale('en'));
      final freshDb = AppDatabase.memory();
      final freshRepository = AssistantRepository(
        freshDb,
        preferences: _MemoryPreferences(),
      );
      final resolvingName = Completer<void>();
      final freshProvider = AssistantProvider(
        repository: freshRepository,
        models: _NoModels(),
        loadDefaultName: () async {
          resolvingName.complete();
          await locale.load();
          return AppL10nService.instance.current.v2AssistantDefaultName;
        },
      );
      addTearDown(() async {
        freshProvider.dispose();
        await freshDb.close();
      });

      final restoringLocale = locale.load();
      final first = freshProvider.ensureLoaded();
      expect(identical(first, freshProvider.ensureLoaded()), isTrue);
      await resolvingName.future;
      expect(freshProvider.loaded, isFalse);
      expect(await freshRepository.assistants(), isEmpty);
      prefs.pending.complete('zh');
      await Future.wait([restoringLocale, first]);
      expect(prefs.reads, 1);
      expect(freshProvider.active?.name, 'AI 助手');
      expect((await freshRepository.assistants()).single.name, 'AI 助手');
    },
  );

  test('a cleared name stays empty after saving and reloading', () async {
    await provider.saveProfile(
      const UserProfile(
        name: 'Saved user',
        avatar: '🌿',
        description: 'My description',
      ),
    );
    await provider.saveProfile(
      const UserProfile(avatar: '🌿', description: 'My description'),
    );
    await provider.load();
    expect(provider.profile.name, isEmpty);
    expect(provider.profile.avatar, '🌿');
    expect(provider.profile.description, 'My description');
    expect((await repository.profile()).name, isEmpty);
  });

  test(
    'connection deletion or a changed credential domain revokes frozen requests',
    () {
      final run = config(a);
      expect(run.authorizedBy(a, null), isFalse);
      expect(
        run.authorizedBy(
          a,
          connection.changed({'baseUrl': 'https://other.example'}),
        ),
        isFalse,
      );
      expect(
        run.authorizedBy(a, connection.changed({'credentialRevision': 1})),
        isFalse,
      );
      expect(
        run.authorizedBy(
          a,
          connection.changed({'name': 'renamed', 'revision': 2}),
        ),
        isTrue,
      );
    },
  );
  test(
    'assistant avatars persist and duplicate independently without entering Run inputs',
    () async {
      final original = a.changed({'avatar': '🦙'});
      await provider.save(original);
      await provider.duplicate(original);
      final copy = provider.assistants.singleWhere(
        (item) => item.name == 'A (2)',
      );
      expect(copy.avatar, '🦙');
      await provider.save(original.changed({'avatar': '📚'}));
      expect(
        provider.assistants.singleWhere((item) => item.id == copy.id).avatar,
        '🦙',
      );
      expect(
        config(original).snapshot()['assistant'],
        isNot(contains('avatar')),
      );
      expect(config(original).system, isNot(contains('🦙')));
      expect(Assistant.fromJson({'id': 'old', 'name': 'Old'}).avatar, isEmpty);
    },
  );
  test(
    'settings refresh repairs the deleted assistant preference, including on restart',
    () async {
      await provider.select('a');
      // Simulate the committed deletion before preferences were updated.
      await db.execute('DELETE FROM assistants WHERE id=?', ['a']);
      await provider.load();
      expect(provider.activeId, 'b');
      expect(await repository.preferences.getString('v2.activeAssistant'), 'b');
      await repository.preferences.setString('v2.activeAssistant', 'a');
      final restored = AssistantProvider(
        repository: repository,
        models: _NoModels(),
      );
      await restored.load();
      expect(restored.activeId, 'b');
      expect(await repository.preferences.getString('v2.activeAssistant'), 'b');
      restored.dispose();
    },
  );

  test(
    'a failed credential rotation leaves the previous key and connection intact',
    () async {
      final original = await repository.saveConnection(
        connection,
        key: 'old-fixture-secret',
      );
      await db.execute(
        "CREATE TRIGGER reject_connection BEFORE UPDATE ON ai_connections BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(
        repository.saveConnection(
          connection.changed({'baseUrl': 'https://other.example'}),
          key: 'new-fixture-secret',
        ),
        throwsA(anything),
      );
      final saved = (await repository.connections()).singleWhere(
        (c) => c.id == connection.id,
      );
      expect(saved.credentialRevision, original.credentialRevision);
      expect(saved.baseUrl, connection.baseUrl);
      expect(saved.apiKey, 'old-fixture-secret');
      expect(jsonEncode(saved.toJson()), contains('fixture-secret'));
    },
  );
  Widget app(Widget child) => ChangeNotifierProvider.value(
    value: provider,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
  Widget launcher(Widget page) => app(
    Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => page),
          ),
          child: const Text('Open editor'),
        ),
      ),
    ),
  );
  const textSaveWait = Duration(milliseconds: 450);
  Future<void> waitFor(WidgetTester tester, bool Function() completed) async {
    for (var attempt = 0; attempt < 100 && !completed(); attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
    }
    expect(completed(), isTrue, reason: 'The assistant change did not finish');
    await tester.pumpAndSettle();
  }

  Future<void> saveEditor(WidgetTester tester, AppLocalizations l) async {
    await tester.tap(find.text(l.commonSave));
    await tester.pumpAndSettle();
  }

  testWidgets('assistant search filters by name and can be cleared', (
    tester,
  ) async {
    await tester.pumpWidget(app(const AssistantsPage()));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(AssistantsPage)))!;
    final search = find.byKey(const Key('assistant_search'));
    Finder assistantRow(String name) => find.byWidgetPredicate(
      (widget) =>
          widget is ListTile &&
          widget.title is Text &&
          (widget.title as Text).data == name,
    );
    expect(search, findsOneWidget);

    await tester.enterText(search, 'missing');
    await tester.pump();
    expect(find.text(l.v2AssistantNoResults), findsOneWidget);
    expect(assistantRow(a.name), findsNothing);
    expect(assistantRow(b.name), findsNothing);

    await tester.enterText(search, 'a');
    await tester.pump();
    expect(assistantRow(a.name), findsOneWidget);
    expect(assistantRow(b.name), findsNothing);

    await tester.tap(find.byKey(const Key('assistant_search_clear')));
    await tester.pump();
    expect(assistantRow(a.name), findsOneWidget);
    expect(assistantRow(b.name), findsOneWidget);
  });

  testWidgets(
    'user avatar is a draft until save; reset can also be cancelled',
    (tester) async {
      await tester.pumpWidget(launcher(const ProfilePage()));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(ProfilePage)))!;
      final original = provider.profile.avatar;
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(
        find.byKey(const Key('profile_name')),
        'Local user',
      );
      await tester.enterText(
        find.byKey(const Key('profile_description')),
        'My description',
      );
      expect(find.byKey(const Key('avatar_edit_badge')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('avatar_edit_badge')));
      await tester.tap(find.byKey(const Key('avatar_edit_badge')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avatar_pick_emoji')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🌿'));
      await tester.pumpAndSettle();
      expect(provider.profile.avatar, original);
      expect(
        tester.widget<IdentityAvatar>(find.byType(IdentityAvatar)).value,
        '🌿',
      );
      await saveEditor(tester, l);
      expect(provider.profile.avatar, '🌿');
      expect(provider.profile.name, 'Local user');
      expect(provider.profile.description, 'My description');
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('avatar_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.v2AvatarReset));
      await tester.pumpAndSettle();
      expect(
        tester.widget<IdentityAvatar>(find.byType(IdentityAvatar)).value,
        isEmpty,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect((await repository.profile()).avatar, '🌿');
    },
  );

  testWidgets(
    'creating an assistant asks only for a name and then opens its editor',
    (tester) async {
      await tester.pumpWidget(app(const AssistantsPage()));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AssistantsPage)),
      )!;

      await tester.tap(find.byKey(const Key('assistant_add')));
      await tester.pumpAndSettle();
      expect(find.text(l.v2AssistantAddTitle), findsOneWidget);
      expect(find.byKey(const Key('assistant_add_name')), findsOneWidget);
      expect(find.byKey(const Key('assistant_instructions')), findsNothing);
      expect(find.byType(AssistantEditor), findsNothing);

      await tester.tap(find.byKey(const Key('assistant_add_button')));
      await tester.pump();
      expect(find.text(l.v2AssistantNameRequired), findsOneWidget);
      expect(provider.assistants, hasLength(2));

      await tester.enterText(
        find.byKey(const Key('assistant_add_name')),
        'Reading assistant',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('assistant_add_button')));
      await waitFor(
        tester,
        () => find.byType(AssistantEditor).evaluate().isNotEmpty,
      );

      final created = provider.assistants.singleWhere(
        (item) => item.name == 'Reading assistant',
      );
      expect(created.id, isNotEmpty);
      expect(
        (await repository.assistants())
            .singleWhere((item) => item.id == created.id)
            .name,
        'Reading assistant',
      );
      expect(find.widgetWithText(AppBar, 'Reading assistant'), findsOneWidget);
      expect(find.text(l.commonSave), findsNothing);
    },
  );

  testWidgets(
    'assistant text, avatar and tool edits persist without a Save action',
    (tester) async {
      await tester.pumpWidget(launcher(const AssistantEditor(assistant: a)));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AssistantEditor)),
      )!;
      expect(find.text(l.commonSave), findsNothing);

      await tester.enterText(
        find.byKey(const Key('assistant_name')),
        'Book assistant',
      );
      await tester.enterText(
        find.byKey(const Key('assistant_instructions')),
        'Recommend books.',
      );
      await tester.pump(textSaveWait);
      await waitFor(
        tester,
        () =>
            provider.assistants.singleWhere((item) => item.id == 'a').name ==
                'Book assistant' &&
            provider.assistants
                    .singleWhere((item) => item.id == 'a')
                    .instructions ==
                'Recommend books.',
      );

      await tester.tap(find.byKey(const Key('avatar_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avatar_pick_emoji')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('📚'));
      await tester.pumpAndSettle();
      await waitFor(
        tester,
        () =>
            provider.assistants.singleWhere((item) => item.id == 'a').avatar ==
            '📚',
      );

      await tester.scrollUntilVisible(
        find.widgetWithText(CheckboxListTile, l.v2ToolClock),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, l.v2ToolClock));
      await waitFor(
        tester,
        () => provider.assistants
            .singleWhere((item) => item.id == 'a')
            .tools
            .contains('clock'),
      );

      final saved = (await repository.assistants()).singleWhere(
        (item) => item.id == 'a',
      );
      expect(saved.name, 'Book assistant');
      expect(saved.instructions, 'Recommend books.');
      expect(saved.avatar, '📚');
      expect(saved.tools, contains('clock'));
    },
  );

  testWidgets('leaving the editor flushes pending name and instructions', (
    tester,
  ) async {
    await tester.pumpWidget(launcher(const AssistantEditor(assistant: a)));
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('assistant_name')),
      'Flushed assistant',
    );
    await tester.enterText(
      find.byKey(const Key('assistant_instructions')),
      'Flushed instructions',
    );

    await tester.pageBack();
    await waitFor(
      tester,
      () => find.byType(AssistantEditor).evaluate().isEmpty,
    );
    final saved = (await repository.assistants()).singleWhere(
      (item) => item.id == 'a',
    );
    expect(saved.name, 'Flushed assistant');
    expect(saved.instructions, 'Flushed instructions');
  });

  testWidgets(
    'an empty assistant name is rejected and blocks leaving the editor',
    (tester) async {
      await tester.pumpWidget(launcher(const AssistantEditor(assistant: a)));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AssistantEditor)),
      )!;
      await tester.enterText(find.byKey(const Key('assistant_name')), '   ');
      await tester.pageBack();
      await waitFor(
        tester,
        () => find.text(l.v2AssistantNameRequired).evaluate().isNotEmpty,
      );
      expect(find.byType(AssistantEditor), findsOneWidget);
      expect(
        (await repository.assistants())
            .singleWhere((item) => item.id == 'a')
            .name,
        'A',
      );

      await tester.enterText(find.byKey(const Key('assistant_name')), 'A');
      await tester.pageBack();
      await waitFor(
        tester,
        () => find.byType(AssistantEditor).evaluate().isEmpty,
      );
    },
  );

  testWidgets(
    'tool tab changes persist immediately and preserve unrelated settings',
    (tester) async {
      const skill = SkillRecord(
        id: 'skill',
        name: 'Writing skill',
        path: '/fixture',
        hash: 'hash',
        description: 'Writing',
      );
      const server = McpServer(
        id: '12345678-server',
        name: 'Lookup MCP',
        url: 'https://example.com/mcp',
        tools: [
          {'name': 'lookup'},
        ],
      );
      final catalog = AgentRepository(db);
      await catalog.saveSkill(skill);
      await catalog.saveServer(server);
      final original = a.changed({
        'temperature': 0.25,
        'maxTokens': 4096,
        'maxTurns': 3,
        'maxToolCalls': 5,
      });
      await provider.save(original);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(launcher(AssistantEditor(assistant: original)));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AssistantEditor)),
      )!;
      Future<void> tapVisible(Finder target) async {
        await tester.scrollUntilVisible(
          target,
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      await tapVisible(find.widgetWithText(CheckboxListTile, l.v2ToolClock));
      await tapVisible(find.widgetWithText(Tab, l.v2Skills));
      await tapVisible(find.widgetWithText(CheckboxListTile, skill.name));
      await tapVisible(find.widgetWithText(Tab, l.v2Mcp));
      await tapVisible(find.text(server.name));
      await tapVisible(find.widgetWithText(CheckboxListTile, 'lookup'));
      await waitFor(tester, () {
        final current = provider.assistants.singleWhere(
          (a) => a.id == original.id,
        );
        return current.tools.contains('clock') &&
            current.tools.contains(
              AgentToolService.mcpToolName(server.id, 'lookup'),
            ) &&
            current.skillIds.contains(skill.id) &&
            current.mcpServerIds.contains(server.id);
      });
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1800));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('assistant_name')),
        'Edited assistant',
      );
      await tester.pageBack();
      await waitFor(
        tester,
        () => find.byType(AssistantEditor).evaluate().isEmpty,
      );
      final saved = (await repository.assistants()).firstWhere(
        (a) => a.id == original.id,
      );
      expect(saved.name, 'Edited assistant');
      expect(
        saved.tools,
        containsAll([
          'clock',
          AgentToolService.mcpToolName(server.id, 'lookup'),
        ]),
      );
      expect(saved.skillIds, [skill.id]);
      expect(saved.mcpServerIds, [server.id]);
      expect(saved.temperature, 0.25);
      expect(saved.maxTokens, 4096);
      expect(saved.maxTurns, 3);
      expect(saved.maxToolCalls, 5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stale skill and MCP grants are pruned and persisted when editing',
    (tester) async {
      const skill = SkillRecord(
        id: 'skill',
        name: 'Writing skill',
        path: '/fixture',
        hash: 'hash',
        description: 'Writing',
      );
      const server = McpServer(
        id: '12345678-server',
        name: 'Lookup MCP',
        url: 'https://example.com/mcp',
        tools: [
          {'name': 'lookup'},
        ],
      );
      final catalog = AgentRepository(db);
      await catalog.saveSkill(skill);
      await catalog.saveServer(server);
      final original = a.changed({
        'tools': ['clock', AgentToolService.mcpToolName(server.id, 'lookup')],
        'skillIds': [skill.id],
        'mcpServerIds': [server.id],
      });
      await provider.save(original);
      await db.execute('DELETE FROM skills');
      await db.execute('DELETE FROM mcp_servers');
      await tester.pumpWidget(launcher(AssistantEditor(assistant: original)));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await waitFor(tester, () {
        final current = provider.assistants.singleWhere(
          (a) => a.id == original.id,
        );
        return current.tools.length == 1 &&
            current.tools.single == 'clock' &&
            current.skillIds.isEmpty &&
            current.mcpServerIds.isEmpty;
      });
      final saved = (await repository.assistants()).firstWhere(
        (a) => a.id == original.id,
      );
      expect(saved.tools, ['clock']);
      expect(saved.skillIds, isEmpty);
      expect(saved.mcpServerIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
