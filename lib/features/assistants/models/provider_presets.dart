import 'package:servllama/features/assistants/models/assistant.dart';

/// Declaration order is the initial display order. Missing presets append to
/// the saved catalog without replacing user edits or reordering existing rows.
const providerPresets = <AiConnection>[
  AiConnection(
    id: 'preset:openai',
    name: 'OpenAI',
    protocol: AiProtocol.openai,
    baseUrl: 'https://api.openai.com/v1',
    enabled: false,
  ),
  AiConnection(
    id: 'preset:anthropic',
    name: 'Anthropic',
    protocol: AiProtocol.anthropic,
    baseUrl: 'https://api.anthropic.com/v1',
    enabled: false,
  ),
  AiConnection(
    id: 'preset:gemini',
    name: 'Google Gemini',
    protocol: AiProtocol.gemini,
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    enabled: false,
  ),
  AiConnection(
    id: 'preset:deepseek',
    name: 'DeepSeek',
    protocol: AiProtocol.openai,
    baseUrl: 'https://api.deepseek.com/v1',
    enabled: false,
  ),
  AiConnection(
    id: 'preset:openrouter',
    name: 'OpenRouter',
    protocol: AiProtocol.openai,
    baseUrl: 'https://openrouter.ai/api/v1',
    enabled: false,
  ),
  AiConnection(
    id: 'preset:siliconflow',
    name: 'SiliconFlow',
    protocol: AiProtocol.openai,
    baseUrl: 'https://api.siliconflow.cn/v1',
    enabled: false,
  ),
  AiConnection(
    id: 'preset:aliyun',
    name: 'Alibaba Cloud',
    protocol: AiProtocol.openai,
    baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
    enabled: false,
  ),
  AiConnection(
    id: 'preset:zhipu',
    name: 'Zhipu AI',
    protocol: AiProtocol.openai,
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    enabled: false,
  ),
];

bool isPresetProvider(String id) => providerPresets.any((p) => p.id == id);
