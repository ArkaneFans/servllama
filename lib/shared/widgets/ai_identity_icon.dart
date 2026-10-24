import 'package:flutter/material.dart';
import 'package:servllama/shared/widgets/bundled_svg_asset.dart';

/// Presentation only: a logo never implies capabilities or provider trust.
abstract final class AiBrand {
  static const _presets = {
    'openai': 'openai',
    'anthropic': 'anthropic',
    'gemini': 'gemini',
    'deepseek': 'deepseek',
    'openrouter': 'openrouter',
    'siliconflow': 'siliconcloud',
    'aliyun': 'alibabacloud',
    'zhipu': 'zhipu',
  };
  static final _providerNames = <(RegExp, String)>[
    (
      RegExp(r'(^|[^a-z0-9])(openai|chatgpt|gpt|o[134])(?=$|[^a-z0-9])'),
      'openai',
    ),
    (RegExp(r'(^|[^a-z0-9])anthropic(?=$|[^a-z0-9])'), 'anthropic'),
    (RegExp(r'(^|[^a-z0-9])claude(?=$|[^a-z0-9])'), 'claude'),
    (RegExp(r'(^|[^a-z0-9])(gemini|google)(?=$|[^a-z0-9])'), 'gemini'),
    (RegExp(r'(^|[^a-z0-9])deepseek(?=$|[^a-z0-9])'), 'deepseek'),
    (RegExp(r'(^|[^a-z0-9])openrouter(?=$|[^a-z0-9])'), 'openrouter'),
    (
      RegExp(r'(^|[^a-z0-9])(siliconflow|siliconcloud|硅基流动)(?=$|[^a-z0-9])'),
      'siliconcloud',
    ),
    (
      RegExp(
        r'(^|[^a-z0-9])(aliyun|alibabacloud|dashscope|阿里云|百炼)(?=$|[^a-z0-9])',
      ),
      'alibabacloud',
    ),
    (RegExp(r'(^|[^a-z0-9])(zhipu|zhipuai|glm|智谱)(?=$|[^a-z0-9])'), 'zhipu'),
    (RegExp(r'(^|[^a-z0-9])(xai|x\.ai|grok)(?=$|[^a-z0-9])'), 'grok'),
    (RegExp(r'(^|[^a-z0-9])moonshot(?=$|[^a-z0-9])'), 'moonshot'),
    (RegExp(r'(^|[^a-z0-9])(kimi|月之暗面)(?=$|[^a-z0-9])'), 'kimi'),
    (RegExp(r'(^|[^a-z0-9])(minimax|minimaxi)(?=$|[^a-z0-9])'), 'minimax'),
    (
      RegExp(
        r'(^|[^a-z0-9])(mistral|mixtral|magistral|ministral|devstral|codestral|pixtral|voxtral)(?=$|[^a-z0-9])',
      ),
      'mistral',
    ),
    (RegExp(r'(^|[^a-z0-9])(qwen|qwq|qvq|通义千问)(?=$|[^a-z0-9])'), 'qwen'),
    (RegExp(r'(^|[^a-z0-9])(doubao|豆包)(?=$|[^a-z0-9])'), 'doubao'),
    (RegExp(r'(^|[^a-z0-9])(yi|零一万物)(?=$|[^a-z0-9])'), 'yi'),
    (RegExp(r'(^|[^a-z0-9])(microsoft|azure)(?=$|[^a-z0-9])'), 'microsoft'),
    (RegExp(r'(^|[^a-z0-9])(meta|llama)(?=$|[^a-z0-9])'), 'meta'),
    (RegExp(r'(^|[^a-z0-9])gemma(?=$|[^a-z0-9])'), 'gemma'),
    (RegExp(r'(^|[^a-z0-9])huggingface(?=$|[^a-z0-9])'), 'huggingface'),
  ];
  static final _families = <(RegExp, String)>[
    (RegExp(r'^(deepseek)(?=$|[\d._-])'), 'deepseek'),
    (RegExp(r'^(qwen|qwq)(?=$|[\d._-])'), 'qwen'),
    (RegExp(r'^(claude)(?=$|[\d._-])'), 'claude'),
    (RegExp(r'^(gemini)(?=$|[\d._-])'), 'gemini'),
    (RegExp(r'^(gemma)(?=$|[\d._-])'), 'gemma'),
    (RegExp(r'^(gpt|chatgpt|o[134])(?=$|[\d._-])'), 'openai'),
    (RegExp(r'^(llama|meta-llama)(?=$|[\d._-])'), 'meta'),
    (
      RegExp(
        r'^(mistral|mixtral|ministral|codestral|devstral|magistral)(?=$|[\d._-])',
      ),
      'mistral',
    ),
    (RegExp(r'^(glm|chatglm)(?=$|[\d._-])'), 'zhipu'),
    (RegExp(r'^(grok)(?=$|[\d._-])'), 'grok'),
    (RegExp(r'^(kimi)(?=$|[\d._-])'), 'kimi'),
    (RegExp(r'^(moonshot)(?=$|[\d._-])'), 'moonshot'),
    (RegExp(r'^(minimax)(?=$|[\d._-])'), 'minimax'),
    (RegExp(r'^(doubao)(?=$|[\d._-])'), 'doubao'),
    (RegExp(r'^(yi)(?=$|[\d._-])'), 'yi'),
    (RegExp(r'^(phi)(?=$|[\d._-])'), 'microsoft'),
  ];

  static String? model(String? value) {
    if (value == null) return null;
    // Check the actual model before organization names (including distill names).
    for (final part
        in value
            .trim()
            .toLowerCase()
            .replaceAll(' ', '-')
            .split('/')
            .reversed) {
      for (final (pattern, brand) in _families) {
        if (pattern.hasMatch(part)) return brand;
      }
    }
    return null;
  }

  static String? provider({String? id, String? name}) {
    if (id != null && id.startsWith('preset:')) {
      final brand = _presets[id.substring(7)];
      if (brand != null) return brand;
    }
    final providerName = (name ?? '').trim().toLowerCase();
    for (final (pattern, brand) in _providerNames) {
      if (pattern.hasMatch(providerName)) return brand;
    }
    final normalized = providerName.replaceAll(RegExp(r'[\s_-]'), '');
    return switch (normalized) {
      'google' || 'googlegemini' => 'gemini',
      'alibabacloud' || '阿里云' || '通义千问' => 'alibabacloud',
      '硅基流动' || 'siliconcloud' => 'siliconcloud',
      'zhipuai' || '智谱' => 'zhipu',
      'xai' => 'grok',
      _ => _presets[normalized],
    };
  }
}

class AiIdentityIcon extends StatelessWidget {
  const AiIdentityIcon({
    super.key,
    this.model,
    this.providerId,
    this.providerName,
    this.local = false,
    this.size = 40,
    this.framed = true,
  });
  final String? model, providerId, providerName;
  final bool local, framed;
  final double size;

  String? get _fallbackCharacter {
    final value = model?.trim().isNotEmpty == true
        ? model!.trim()
        : providerName?.trim().isNotEmpty == true
        ? providerName!.trim()
        : null;
    return value?.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final brand =
        AiBrand.model(model) ??
        AiBrand.provider(id: providerId, name: providerName);
    final c = Theme.of(context).colorScheme;
    final fallback = _fallbackCharacter;
    final glyph = brand != null
        ? BundledSvgAsset(
            'assets/ai-icons/$brand.svg',
            // Preserve brand fills/gradients; only currentColor follows theme.
            currentColor: c.onSurface,
            width: framed ? size * .6 : size,
            height: framed ? size * .6 : size,
          )
        : fallback != null
        ? FittedBox(
            child: Text(
              fallback,
              maxLines: 1,
              style: TextStyle(
                color: c.primary,
                fontWeight: FontWeight.w700,
                fontSize: size * (framed ? .42 : .68),
              ),
            ),
          )
        : Icon(
            local
                ? Icons.memory_outlined
                : model != null
                ? Icons.auto_awesome_outlined
                : Icons.cloud_outlined,
            size: framed ? size * .6 : size,
            color: c.onSurfaceVariant,
          );
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: framed
            ? BoxDecoration(
                color: c.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        alignment: Alignment.center,
        child: glyph,
      ),
    );
  }
}
