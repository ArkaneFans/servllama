import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/model_asset.dart';
import 'package:servllama/core/repositories/unified_model_repository.dart';
import 'package:servllama/core/security/secret_store.dart';
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
  Future<List<ModelAsset>> listAssets({bool reconcile = true}) async => [];
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late AssistantRepository repository;
  late AssistantProvider provider;
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
  });
  ChatRunConfig config(Assistant assistant) => ChatRunConfig(
    assistant: assistant,
    connection: connection,
    key: 'not-persisted',
    modelId: 'model',
    isLocal: false,
  );

  test('new profiles stay empty without an initialization write', () async {
    expect(provider.profile.name, isEmpty);
    expect(provider.profile.avatar, isEmpty);
    final profile = await repository.profile();
    expect(profile.name, isEmpty);
    expect(profile.avatar, isEmpty);
    expect(profile.description, isEmpty);
    expect(await repository.preferences.getString('v2.userProfile'), isNull);
  });

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
    'historical profile grants are ignored and omitted from new Run inputs',
    () async {
      await repository.saveProfile(
        const UserProfile(
          name: 'Private nickname',
          description: 'Private description',
        ),
      );
      final selected = a.changed({
        'instructions': 'Only these instructions',
        'useProfile': true,
        'profileFields': ['addressAs', 'preferences'],
      });
      final run = config(selected);
      expect(run.system, 'Only these instructions');
      expect(run.snapshot(), isNot(contains('profile')));
      expect(jsonEncode(run.snapshot()), isNot(contains('Private')));
      expect(selected.toJson(), isNot(contains('useProfile')));
      expect(selected.toJson(), isNot(contains('profileFields')));
      expect(
        run.authorizedBy(
          selected.changed({'instructions': 'Next turn'}),
          connection,
        ),
        isTrue,
      );
      expect((await repository.profile()).description, 'Private description');
    },
  );
  test(
    'profile reads legacy preferences but only persists the three fields',
    () async {
      await repository.preferences.setString(
        'v2.userProfile',
        jsonEncode({
          'name': 'Local user',
          'avatar': '🌿',
          'addressAs': 'Old form of address',
          'preferences': 'Existing description',
        }),
      );
      final profile = await repository.profile();
      expect(profile.description, 'Existing description');
      await repository.saveProfile(profile);
      final stored =
          jsonDecode(
                (await repository.preferences.getString('v2.userProfile'))!,
              )
              as Map;
      expect(stored.keys, unorderedEquals(['name', 'avatar', 'description']));
      expect(
        UserProfile.fromJson({
          ...stored,
          'description': '',
          'preferences': 'Old',
        }).description,
        isEmpty,
      );
    },
  );

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
        run.authorizedBy(a, connection.changed({'secretRef': 'rotated'})),
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
    'a deleted historical assistant is not replaced by an incidental settings refresh',
    () async {
      await db.execute(
        'INSERT INTO conversations(id,title,created_at,updated_at,message_ids,config) VALUES(?,?,0,0,?,?)',
        [
          'conversation',
          'Old conversation',
          '[]',
          jsonEncode({'assistantId': 'deleted'}),
        ],
      );
      await provider.select('a');
      await provider.load();
      expect(provider.activeId, 'a');
      final row = (await db.query('SELECT config FROM conversations')).single;
      expect(jsonDecode(row.read<String>('config'))['assistantId'], 'deleted');
    },
  );
  test(
    'a failed credential rotation leaves the previous key and connection intact',
    () async {
      final original = await repository.saveConnection(
        connection,
        newSecret: 'old-fixture-secret',
      );
      await db.execute(
        "CREATE TRIGGER reject_connection BEFORE UPDATE ON ai_connections BEGIN SELECT RAISE(ABORT,'fixture'); END",
      );
      await expectLater(
        repository.saveConnection(
          connection.changed({'baseUrl': 'https://other.example'}),
          newSecret: 'new-fixture-secret',
        ),
        throwsA(anything),
      );
      final saved = (await repository.connections()).singleWhere(
        (c) => c.id == connection.id,
      );
      expect(saved.secretRef, original.secretRef);
      expect(saved.baseUrl, connection.baseUrl);
      expect(
        await SecretStore.instance.read(saved.secretRef!),
        'old-fixture-secret',
      );
      expect(jsonEncode(saved.toJson()), isNot(contains('fixture-secret')));
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
  Future<void> saveEditor(WidgetTester tester, AppLocalizations l) async {
    await tester.tap(find.text(l.commonSave));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'assistant management shows only identity without selecting the active assistant',
    (tester) async {
      await provider.save(a.changed({'instructions': 'A system prompt'}));
      await provider.select(a.id);
      await tester.pumpWidget(app(const AssistantsPage()));
      await tester.pumpAndSettle();
      final row = find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.title is Text &&
            (widget.title as Text).data == a.name,
      );
      final tile = tester.widget<ListTile>(row);
      expect(tile.selected, isFalse);
      expect(tile.subtitle, isNull);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.text('A system prompt'), findsNothing);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(AssistantEditor), findsOneWidget);
      expect(find.widgetWithText(AppBar, a.name), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(provider.activeId, a.id);
    },
  );

  testWidgets('profile saves blank names without storing the localized hint', (
    tester,
  ) async {
    await tester.pumpWidget(launcher(const ProfilePage()));
    final nameField = find.byKey(const Key('profile_name'));
    for (final value in ['', '  Updated user  ', '', '   ']) {
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(tester.element(find.byType(ProfilePage)))!;
      final field = tester.widget<TextField>(nameField);
      expect(field.controller!.text, provider.profile.name);
      expect(field.decoration!.hintText, l.v2ChatUserName);
      expect(
        tester.widget<IdentityAvatar>(find.byType(IdentityAvatar)).value,
        isEmpty,
      );
      await tester.enterText(nameField, value);
      await saveEditor(tester, l);
      expect(find.byType(ProfilePage), findsNothing);
      expect(provider.profile.name, value.trim());
      expect((await repository.profile()).name, value.trim());
    }
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
    'assistant name and emoji save together and later cancellation discards both',
    (tester) async {
      await tester.pumpWidget(launcher(const AssistantEditor(assistant: a)));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AssistantEditor)),
      )!;
      await tester.enterText(find.byType(TextField).first, 'Book assistant');
      await tester.tap(find.byKey(const Key('avatar_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('avatar_pick_emoji')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('📚'));
      await tester.pumpAndSettle();
      await saveEditor(tester, l);
      final saved = provider.assistants.singleWhere((item) => item.id == 'a');
      expect(saved.name, 'Book assistant');
      expect(saved.avatar, '📚');
      await tester.pumpWidget(launcher(AssistantEditor(assistant: saved)));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Unsaved name');
      await tester.tap(find.byKey(const Key('avatar_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.v2AvatarReset));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        (await repository.assistants())
            .singleWhere((item) => item.id == 'a')
            .toJson(),
        saved.toJson(),
      );
    },
  );
  testWidgets(
    'assistant form cancellation discards name and local tool grants',
    (tester) async {
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AssistantEditor(assistant: a),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AssistantEditor)),
      )!;
      await tester.enterText(find.byType(TextField).first, 'Unsaved name');
      await tester.scrollUntilVisible(
        find.widgetWithText(CheckboxListTile, l.v2ToolClock),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, l.v2ToolClock));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      final saved = (await repository.assistants()).firstWhere(
        (item) => item.id == 'a',
      );
      expect(saved.name, 'A');
      expect(saved.tools, isEmpty);
    },
  );

  testWidgets(
    'tool tabs share one draft and save after scrolling back to the avatar',
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
      final beforeSave = (await repository.assistants()).firstWhere(
        (a) => a.id == original.id,
      );
      expect(beforeSave.tools, isEmpty);
      expect(beforeSave.skillIds, isEmpty);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1800));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Edited assistant');
      await saveEditor(tester, l);
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
    'saving an open editor does not restore deleted skill or MCP grants',
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
      await tester.pumpWidget(launcher(AssistantEditor(assistant: original)));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      final l = AppLocalizations.of(
        tester.element(find.byType(AssistantEditor)),
      )!;
      await tester.scrollUntilVisible(
        find.byType(TabBar),
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await db.execute('DELETE FROM skills');
      await db.execute('DELETE FROM mcp_servers');
      await catalog.removeAssistantBindings(
        skillId: skill.id,
        serverId: server.id,
      );
      await saveEditor(tester, l);
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
