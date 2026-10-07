import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  static const _domains = {
    'openai.com': 'openai',
    'anthropic.com': 'anthropic',
    'generativelanguage.googleapis.com': 'gemini',
    'deepseek.com': 'deepseek',
    'openrouter.ai': 'openrouter',
    'siliconflow.cn': 'siliconcloud',
    'siliconflow.com': 'siliconcloud',
    'aliyuncs.com': 'alibabacloud',
    'bigmodel.cn': 'zhipu',
    'x.ai': 'grok',
    'moonshot.cn': 'moonshot',
    'moonshot.ai': 'moonshot',
    'minimax.io': 'minimax',
    'minimaxi.com': 'minimax',
    'mistral.ai': 'mistral',
  };
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

  static String? provider({String? id, String? name, String? url}) {
    if (id != null && id.startsWith('preset:')) {
      final brand = _presets[id.substring(7)];
      if (brand != null) return brand;
    }
    final host = Uri.tryParse(url ?? '')?.host.toLowerCase() ?? '';
    for (final entry in _domains.entries) {
      if (host == entry.key || host.endsWith('.${entry.key}')) {
        return entry.value;
      }
    }
    final normalized = (name ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[\s_-]'),
      '',
    );
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
    this.baseUrl,
    this.local = false,
    this.size = 40,
    this.framed = true,
  });
  final String? model, providerId, providerName, baseUrl;
  final bool local, framed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brand =
        AiBrand.model(model) ??
        AiBrand.provider(id: providerId, name: providerName, url: baseUrl);
    final c = Theme.of(context).colorScheme;
    final glyph = brand == null
        ? Icon(
            local
                ? Icons.memory_outlined
                : model != null
                ? Icons.auto_awesome_outlined
                : Icons.cloud_outlined,
            size: framed ? size * .6 : size,
            color: c.onSurfaceVariant,
          )
        : SvgPicture.asset(
            'assets/ai-icons/$brand.svg',
            // Preserve brand fills/gradients; only currentColor follows theme.
            theme: SvgTheme(currentColor: c.onSurface),
            width: framed ? size * .6 : size,
            height: framed ? size * .6 : size,
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
