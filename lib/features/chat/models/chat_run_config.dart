import 'package:servllama/features/assistants/models/assistant.dart';

class ChatRunConfig {
  const ChatRunConfig({
    required this.assistant,
    required this.connection,
    required this.key,
    required this.modelId,
    required this.isLocal,
    this.target,
  });
  final Assistant assistant;
  final AiConnection connection;
  final String key, modelId;
  final bool isLocal;
  final ChatTarget? target;

  ModelCapabilities get capabilities => connection.capabilitiesFor(modelId);

  /// Ordinary edits apply on the next Run. Revoked capabilities and a
  /// changed credential domain invalidate requests that have not started.
  bool authorizedBy(Assistant? current, AiConnection? currentConnection) {
    if (current == null ||
        current.id != assistant.id ||
        !current.tools.toSet().containsAll(assistant.tools) ||
        !current.skillIds.toSet().containsAll(assistant.skillIds) ||
        !current.mcpServerIds.toSet().containsAll(assistant.mcpServerIds) ||
        (assistant.tools.contains('web_search') &&
            current.webSearch.provider != assistant.webSearch.provider)) {
      return false;
    }
    return isLocal ||
        (currentConnection != null &&
            currentConnection.hasModel(modelId) &&
            currentConnection.id == connection.id &&
            currentConnection.baseUrl == connection.baseUrl &&
            currentConnection.protocol == connection.protocol &&
            currentConnection.secretRef == connection.secretRef &&
            (!capabilities.supportsTools ||
                currentConnection.capabilitiesFor(modelId).supportsTools) &&
            (!capabilities.supportsImages ||
                currentConnection.capabilitiesFor(modelId).supportsImages));
  }

  String get system => assistant.instructions;
  Map<String, dynamic> snapshot() => {
    // Avatars belong to display settings, never to generation inputs/history.
    'assistant': assistant.toJson()
      ..remove('avatar')
      ..remove('chatTarget'),
    'connection': connection.toJson(),
    'modelId': modelId,
    'local': isLocal,
    if (target != null) 'target': target!.toJson(),
  };
}
