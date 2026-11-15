import 'package:servllama/features/assistants/models/assistant.dart';

/// Fixed UI levels become the selected protocol's effort or token budget.
void applyReasoningRequest(
  Map<String, dynamic> body,
  AiConnection connection,
  String modelId,
  ReasoningLevel level,
) {
  if (!connection.capabilitiesFor(modelId).supportsThinking) return;
  switch (connection.protocol) {
    case AiProtocol.openai:
      if (level != ReasoningLevel.auto) {
        body['reasoning_effort'] = level.effort;
      }
    case AiProtocol.anthropic:
      if (level == ReasoningLevel.off) {
        body['thinking'] = {'type': 'disabled'};
        return;
      }
      body['thinking'] = {'type': 'adaptive', 'display': 'summarized'};
      if (level != ReasoningLevel.auto) {
        body['output_config'] = {'effort': level.effort};
      }
      body.remove('temperature');
    case AiProtocol.gemini:
      (body['generationConfig'] as Map<String, dynamic>)['thinkingConfig'] = {
        'includeThoughts': level != ReasoningLevel.off,
        if (level != ReasoningLevel.auto) 'thinkingBudget': level.budgetTokens,
      };
  }
}
