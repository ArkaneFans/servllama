enum WebSearchProvider { bing, duckduckgo }

class WebSearchOptions {
  const WebSearchOptions({
    this.provider = WebSearchProvider.bing,
    this.maxResults = 5,
  });

  final WebSearchProvider provider;
  final int maxResults;

  void validate() {
    if (maxResults < 1 || maxResults > 10) {
      throw const FormatException(
        'Search result limit must be between 1 and 10',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'maxResults': maxResults,
  };

  factory WebSearchOptions.fromJson(Map<String, dynamic> json) {
    final options = WebSearchOptions(
      provider: WebSearchProvider.values.byName(json['provider'] ?? 'bing'),
      maxResults: json['maxResults'] ?? 5,
    );
    options.validate();
    return options;
  }
}

class WebSearchItem {
  const WebSearchItem({
    required this.title,
    required this.url,
    required this.snippet,
  });

  final String title, url, snippet;

  Map<String, dynamic> toJson() => {
    'title': title,
    'url': url,
    'snippet': snippet,
  };

  factory WebSearchItem.fromJson(Map<String, dynamic> json) => WebSearchItem(
    title: json['title'] as String,
    url: json['url'] as String,
    snippet: json['snippet'] as String,
  );
}

class WebSearchResult {
  WebSearchResult({
    required this.provider,
    required this.query,
    required this.retrievedAt,
    required List<WebSearchItem> items,
  }) : items = List.unmodifiable(items);

  final WebSearchProvider provider;
  final String query;
  final DateTime retrievedAt;
  final List<WebSearchItem> items;

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'query': query,
    'retrievedAt': retrievedAt.toUtc().toIso8601String(),
    'items': items.map((item) => item.toJson()).toList(),
  };
}

enum WebSearchFailure {
  unavailable,
  rateLimited,
  challenge,
  invalidResponse,
  tooLarge,
  timeout,
}

/// Safe to persist in tool receipts: never includes a query, response or URL.
class WebSearchException implements Exception {
  const WebSearchException(this.reason, {this.statusCode});
  final WebSearchFailure reason;
  final int? statusCode;

  @override
  String toString() =>
      'WebSearchException(${reason.name}'
      '${statusCode == null ? '' : ', HTTP $statusCode'})';
}
