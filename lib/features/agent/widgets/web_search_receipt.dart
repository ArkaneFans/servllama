import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:servllama/features/agent/models/web_search.dart';
import 'package:servllama/l10n/l10n.dart';
import 'package:servllama/shared/widgets/async_action.dart';
import 'package:url_launcher/url_launcher.dart';

class WebSearchReceipt extends StatelessWidget {
  const WebSearchReceipt({super.key, required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (payload['searchFailure'] != null) {
      return Text(switch (payload['searchFailure']) {
        'rateLimited' => l.v2SearchRateLimited,
        'challenge' => l.v2SearchChallenge,
        'invalidResponse' => l.v2SearchInvalidResponse,
        'tooLarge' => l.v2SearchTooLarge,
        'timeout' => l.v2SearchTimeout,
        _ => l.v2SearchUnavailable,
      });
    }
    final raw = payload['result'];
    if (raw is! String) return const SizedBox.shrink();
    final List<WebSearchItem> items;
    final Map<String, dynamic> result;
    try {
      result = Map<String, dynamic>.from(jsonDecode(raw));
      items = (result['items'] as List)
          .map(
            (item) => WebSearchItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (_) {
      // Keep the generic receipt visible for unsupported historical formats.
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(l.v2SearchSources, style: Theme.of(context).textTheme.titleSmall),
        Text(
          result['provider'] == 'duckduckgo'
              ? l.v2SearchDuckDuckGo
              : l.v2SearchBing,
        ),
        if (items.isEmpty) Text(l.v2SearchNoResults),
        for (final item in items) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.title),
            subtitle: Text(
              item.url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => runUiAction(context, () async {
              final uri = Uri.tryParse(item.url);
              if (uri == null ||
                  !const {'https', 'http'}.contains(uri.scheme) ||
                  uri.host.isEmpty ||
                  uri.userInfo.isNotEmpty ||
                  !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                throw StateError(l.v2SearchOpenFailed);
              }
            }),
          ),
          if (item.snippet.isNotEmpty)
            Text(item.snippet, maxLines: 4, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }
}
