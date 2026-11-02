import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/database/app_database.dart';
import 'package:servllama/core/models/inference_engine.dart';
import 'package:servllama/core/providers/engine_runtime_provider.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/assistants/providers/assistant_provider.dart';
import 'package:servllama/features/chat/controllers/chat_runner.dart';
import 'package:servllama/features/chat/models/chat_message_record.dart';
import 'package:servllama/features/chat/models/chat_run_config.dart';
import 'package:servllama/features/chat/models/chat_session_record.dart';
import 'package:servllama/features/chat/models/generation_metrics.dart';
import 'package:servllama/features/chat/providers/chat_provider.dart';
import 'package:servllama/features/chat/repositories/chat_session_repository.dart';
import '../../../support/stub_engine_adapter.dart';

const assistant = Assistant(
  id: 'a',
  name: 'Assistant',
  chatTarget: ChatTarget.remote('c', 'm'),
);
const connection = AiConnection(
  id: 'c',
  name: 'Provider',
  protocol: AiProtocol.openai,
  baseUrl: 'https://example.invalid/v1',
  models: ['m'],
);
const config = ChatRunConfig(
  assistant: assistant,
  connection: connection,
  key: '',
  modelId: 'm',
  isLocal: false,
  target: ChatTarget.remote('c', 'm'),
);

class _Repository extends ChatSessionRepository {
  List<ChatMessageRecord> messages = [];
  int reads = 0;
  @override
  Future<List<ChatMessageRecord>> loadAllMessages(
    ChatSessionRecord session,
  ) async {
    reads++;
    return messages;
  }
}

class _Chat extends ChatProvider {
  _Chat(this.store) : super(repository: store);
  final _Repository store;
  @override
  ChatSessionRecord get selectedSession => ChatSessionRecord(
    id: 's',
    title: 'Session',
    assistantId: 'a',
    messageIds: store.messages.map((m) => m.id).toList(),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  // Simulates a paginated window that only contains the latest response.
  @override
  List<ChatMessageRecord> get visibleMessages =>
      store.messages.isEmpty ? [] : [store.messages.last];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Repository store;
  late _Chat chat;
  late AssistantProvider assistants;
  late EngineRuntimeProvider runtime;
  final user = ChatMessageRecord(
    id: 'u',
    role: ChatRole.user,
    content: 'Hello',
    createdAt: DateTime(2026),
  );
  final response = ChatMessageRecord(
    id: 'r',
    role: ChatRole.assistant,
    content: 'Hi',
    createdAt: DateTime(2026),
  );
  setUp(() {
    AppDatabase.current = null;
    store = _Repository();
    assistants = AssistantProvider()
      ..assistants = [assistant]
      ..connections = [connection]
      ..activeId = 'a'
      ..loaded = true;
    runtime = EngineRuntimeProvider(
      llamaCppAdapter: StubEngineAdapter(engine: InferenceEngine.llamaCpp),
      mnnAdapter: StubEngineAdapter(),
    );
    chat = _Chat(store)..bind(assistants, runtime);
  });
  tearDown(() {
    chat.dispose();
    assistants.dispose();
    runtime.dispose();
    runtime.resources.dispose();
  });
  test(
    'empty, user-only and legacy contexts perform no passive DB read',
    () async {
      for (final messages in <List<ChatMessageRecord>>[
        [],
        [user],
        [user, response],
      ]) {
        store.messages = messages;
        expect(await chat.loadCurrentContextTokens(), isNull);
        expect(store.reads, 0);
      }
    },
  );
  test('other-model provenance performs no passive DB read', () async {
    store.messages = [
      user,
      response.copyWith(
        generationMetrics: const GenerationMetrics(
          inputTokens: 10,
          outputTokens: 5,
          modelId: 'other',
          connectionId: 'c',
          contextKey: 'x',
        ),
      ),
    ];
    expect(await chat.loadCurrentContextTokens(), isNull);
    expect(store.reads, 0);
  });
  test(
    'eligible response verifies full prefix outside the visible window',
    () async {
      store.messages = [
        user,
        response.copyWith(
          generationMetrics: GenerationMetrics(
            inputTokens: 10,
            outputTokens: 5,
            modelId: 'm',
            connectionId: 'c',
            contextKey: ChatRunner.historyContextKey(config, [user]),
          ),
        ),
      ];
      expect(chat.visibleMessages, hasLength(1));
      expect(await chat.loadCurrentContextTokens(), 15);
      expect(store.reads, 1);
      store.messages = [
        user.copyWith(content: 'Edited hidden prefix'),
        store.messages.last,
      ];
      expect(await chat.loadCurrentContextTokens(), isNull);
      expect(store.reads, 2);
    },
  );
}
