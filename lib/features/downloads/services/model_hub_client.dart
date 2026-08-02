import 'package:dio/dio.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';

/// Typed failures so the page layer can localize them (AGENTS.md keeps
/// display text out of services).
enum ModelHubErrorKind { network, unauthorized, notFound, malformedResponse }

class ModelHubException implements Exception {
  const ModelHubException(this.kind, {this.detail});

  final ModelHubErrorKind kind;
  final String? detail;

  @override
  String toString() => detail ?? kind.name;
}

/// Search / browse / resolve-download-url for one model hub.
abstract class ModelHubClient {
  ModelHubSource get source;

  Set<HubModelFormat> get searchableFormats;

  Future<HubSearchPage> search(
    String query, {
    required HubModelFormat format,
    int limit = 20,
    String? pageToken,
  });

  Future<HubRepoDetail> fetchRepo(
    String repoId, {
    HubModelFormat? expectedFormat,
  });

  /// Direct download URL for [filePath]. Both hubs answer with a 302 to a
  /// CDN that honours `Range`, so the downloader just follows redirects.
  String downloadUrl(String repoId, String filePath, {String? revision});

  Map<String, String> authHeaders(String? token);
}

/// Verified against the live API on 2026-07-29:
/// - `GET /api/models?search=&filter=gguf&limit=&sort=downloads`
/// - `GET /api/models/{repo}/tree/{rev}?recursive=true`
/// - `GET /{repo}/resolve/{rev}/{path}` → 302 CDN, `Accept-Ranges: bytes`
class HuggingFaceHubClient implements ModelHubClient {
  HuggingFaceHubClient({Dio? dio, String? host})
    : _dio = dio ?? _defaultDio(),
      _host = host ?? officialHost;

  static const String officialHost = 'https://huggingface.co';

  /// Mainland-China mirror. Same path layout, so only the origin differs.
  static const String mirrorHost = 'https://hf-mirror.com';

  static Dio _defaultDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      validateStatus: (_) => true,
    ),
  );

  final Dio _dio;
  final String _host;

  @override
  ModelHubSource get source => ModelHubSource.huggingFace;

  @override
  Set<HubModelFormat> get searchableFormats => const <HubModelFormat>{
    HubModelFormat.gguf,
  };

  @override
  Map<String, String> authHeaders(String? token) {
    final trimmed = token?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $trimmed'};
  }

  @override
  Future<HubSearchPage> search(
    String query, {
    required HubModelFormat format,
    int limit = 20,
    String? pageToken,
  }) async {
    if (!searchableFormats.contains(format)) {
      return const HubSearchPage(items: <HubRepoSummary>[]);
    }
    final response = await _getResponse(
      '$_host/api/models',
      queryParameters: <String, dynamic>{
        if (query.isNotEmpty) 'search': query,
        // The public API uses `filter`; `library=gguf` is a web-page query
        // parameter and is ignored when sent directly to `/api/models`.
        'filter': format.libraryTag,
        'limit': limit,
        'sort': 'downloads',
        'direction': -1,
        // The full response includes `siblings`, which lets the result card
        // show a file count without opening every repository individually.
        'full': true,
        if (pageToken != null) 'cursor': pageToken,
      },
    );
    final data = response.data;
    if (data is! List) {
      throw const ModelHubException(ModelHubErrorKind.malformedResponse);
    }

    final results = <HubRepoSummary>[];
    for (final item in data) {
      if (item is! Map) {
        continue;
      }
      final repoId = '${item['id'] ?? item['modelId'] ?? ''}'.trim();
      if (repoId.isEmpty) {
        continue;
      }
      final tags =
          (item['tags'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[];
      if (!_hasHuggingFaceFormatEvidence(item, tags, format)) {
        continue;
      }
      final segments = repoId.split('/');
      results.add(
        HubRepoSummary(
          source: source,
          format: format,
          repoId: repoId,
          owner: segments.length > 1 ? segments.first : '',
          name: segments.last,
          downloads: (item['downloads'] as num?)?.toInt() ?? 0,
          likes: (item['likes'] as num?)?.toInt() ?? 0,
          lastModified: DateTime.tryParse('${item['lastModified'] ?? ''}'),
          fileCount: item['siblings'] is List
              ? (item['siblings'] as List).length
              : null,
          tags: tags,
        ),
      );
    }
    return HubSearchPage(
      items: results,
      nextPageToken: _nextCursor(response.headers),
    );
  }

  @override
  Future<HubRepoDetail> fetchRepo(
    String repoId, {
    HubModelFormat? expectedFormat,
  }) async {
    final detail = await _get<Map<String, dynamic>>(
      '$_host/api/models/$repoId',
    );
    final revision = 'main';
    final tree = await _get<List<dynamic>>(
      '$_host/api/models/$repoId/tree/$revision',
      queryParameters: <String, dynamic>{'recursive': true},
    );

    final files = <HubRepoFile>[];
    for (final item in tree) {
      if (item is! Map || item['type'] != 'file') {
        continue;
      }
      final path = '${item['path'] ?? ''}'.trim();
      if (path.isEmpty) {
        continue;
      }
      final lfs = item['lfs'];
      files.add(
        HubRepoFile(
          path: path,
          // Plain `size` is the pointer size for LFS blobs; the real byte
          // count lives inside the lfs object.
          sizeBytes:
              (lfs is Map ? (lfs['size'] as num?)?.toInt() : null) ??
              (item['size'] as num?)?.toInt() ??
              0,
          sha256: lfs is Map ? lfs['oid'] as String? : null,
        ),
      );
    }

    final segments = repoId.split('/');
    return HubRepoDetail(
      summary: HubRepoSummary(
        source: source,
        format: expectedFormat ?? _formatFromFiles(files),
        repoId: repoId,
        owner: segments.length > 1 ? segments.first : '',
        name: segments.last,
        downloads: (detail['downloads'] as num?)?.toInt() ?? 0,
        likes: (detail['likes'] as num?)?.toInt() ?? 0,
        lastModified: DateTime.tryParse('${detail['lastModified'] ?? ''}'),
        fileCount: files.length,
        tags:
            (detail['tags'] as List?)?.whereType<String>().toList(
              growable: false,
            ) ??
            const <String>[],
      ),
      files: files,
      revision: revision,
    );
  }

  @override
  String downloadUrl(String repoId, String filePath, {String? revision}) =>
      '$_host/$repoId/resolve/${revision ?? 'main'}/$filePath';

  Future<T> _get<T>(String url, {Map<String, dynamic>? queryParameters}) async {
    final response = await _getResponse(url, queryParameters: queryParameters);
    final data = response.data;
    if (data is! T) {
      throw const ModelHubException(ModelHubErrorKind.malformedResponse);
    }
    return data;
  }

  Future<Response<dynamic>> _getResponse(
    String url, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(url, queryParameters: queryParameters);
    } on DioException catch (error) {
      throw ModelHubException(ModelHubErrorKind.network, detail: error.message);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ModelHubException(ModelHubErrorKind.unauthorized);
    }
    if (response.statusCode == 404) {
      throw const ModelHubException(ModelHubErrorKind.notFound);
    }
    if (response.statusCode != 200) {
      throw ModelHubException(
        ModelHubErrorKind.malformedResponse,
        detail: 'HTTP ${response.statusCode}',
      );
    }
    return response;
  }

  HubModelFormat _formatFromFiles(List<HubRepoFile> files) =>
      files.any((file) => file.isMnnModel)
      ? HubModelFormat.mnn
      : HubModelFormat.gguf;

  bool _hasHuggingFaceFormatEvidence(
    Map<dynamic, dynamic> item,
    List<String> tags,
    HubModelFormat format,
  ) {
    if (tags.any((tag) => tag.toLowerCase() == format.libraryTag)) {
      return true;
    }
    final siblings = item['siblings'];
    if (siblings is! List) {
      return false;
    }
    return siblings.whereType<Map>().any((file) {
      final path = '${file['rfilename'] ?? file['path'] ?? ''}'.toLowerCase();
      return switch (format) {
        HubModelFormat.gguf => path.endsWith('.gguf'),
        HubModelFormat.mnn => path.endsWith('.mnn'),
      };
    });
  }

  String? _nextCursor(Headers headers) {
    final link = headers.value('link');
    if (link == null || link.isEmpty) {
      return null;
    }
    for (final match in RegExp(
      r'<([^>]+)>;\s*rel="?next"?',
      caseSensitive: false,
    ).allMatches(link)) {
      final uri = Uri.tryParse(match.group(1) ?? '');
      final cursor = uri?.queryParameters['cursor'];
      if (cursor != null && cursor.isNotEmpty) {
        return cursor;
      }
    }
    return null;
  }
}

/// Verified against the live API on 2026-07-29:
/// - `PUT /api/v1/dolphin/models` (JSON body) → `Data.Model.Models[]`
/// - `GET /api/v1/models/{repo}/repo/files?Revision=master&Root=`
/// - `GET /models/{repo}/resolve/master/{path}` → 302 CDN, `Range` → 206
class ModelScopeHubClient implements ModelHubClient {
  ModelScopeHubClient({Dio? dio}) : _dio = dio ?? _defaultDio();

  static const String host = 'https://modelscope.cn';
  static const String defaultRevision = 'master';

  static Dio _defaultDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      validateStatus: (_) => true,
    ),
  );

  final Dio _dio;

  @override
  ModelHubSource get source => ModelHubSource.modelScope;

  @override
  Set<HubModelFormat> get searchableFormats => const <HubModelFormat>{
    HubModelFormat.gguf,
    HubModelFormat.mnn,
  };

  @override
  Map<String, String> authHeaders(String? token) {
    final trimmed = token?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $trimmed'};
  }

  @override
  Future<HubSearchPage> search(
    String query, {
    required HubModelFormat format,
    int limit = 20,
    String? pageToken,
  }) async {
    if (!searchableFormats.contains(format)) {
      return const HubSearchPage(items: <HubRepoSummary>[]);
    }
    final pageNumber = int.tryParse(pageToken ?? '') ?? 1;
    final Response<dynamic> response;
    try {
      response = await _dio.put<dynamic>(
        '$host/api/v1/dolphin/models',
        data: <String, dynamic>{
          'PageSize': limit,
          'PageNumber': pageNumber,
          'SortBy': 'Default',
          'Target': '',
          'SingleCriterion': <dynamic>[],
          'Criterion': <Map<String, dynamic>>[
            <String, dynamic>{
              'category': 'libraries',
              'predicate': 'contains',
              'values': <String>[format.libraryTag],
            },
          ],
          'Name': query,
        },
        options: Options(headers: const {'Content-Type': 'application/json'}),
      );
    } on DioException catch (error) {
      throw ModelHubException(ModelHubErrorKind.network, detail: error.message);
    }

    final models = _dataOf(response)?['Model'];
    final list = models is Map ? models['Models'] : null;
    if (list is! List) {
      return const HubSearchPage(items: <HubRepoSummary>[]);
    }

    final results = <HubRepoSummary>[];
    for (final item in list) {
      if (item is! Map) {
        continue;
      }
      final owner = '${item['Path'] ?? ''}'.trim();
      final name = '${item['Name'] ?? ''}'.trim();
      if (owner.isEmpty || name.isEmpty) {
        continue;
      }
      final tags =
          (item['Tags'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[];
      if (!_hasModelScopeFormatEvidence(item, tags, format)) {
        continue;
      }
      final updatedSeconds = (item['LastUpdatedTime'] as num?)?.toInt();
      results.add(
        HubRepoSummary(
          source: source,
          format: format,
          repoId: '$owner/$name',
          owner: owner,
          name: name,
          downloads: (item['Downloads'] as num?)?.toInt() ?? 0,
          likes: (item['Stars'] as num?)?.toInt() ?? 0,
          lastModified: updatedSeconds == null || updatedSeconds <= 0
              ? null
              : DateTime.fromMillisecondsSinceEpoch(updatedSeconds * 1000),
          fileCount: _modelScopeFileCount(item),
          tags: tags,
        ),
      );
    }
    final totalCount = models is Map
        ? (models['TotalCount'] as num?)?.toInt()
        : null;
    final hasMore = totalCount == null
        ? list.length >= limit
        : pageNumber * limit < totalCount;
    return HubSearchPage(
      items: results,
      nextPageToken: hasMore ? '${pageNumber + 1}' : null,
    );
  }

  @override
  Future<HubRepoDetail> fetchRepo(
    String repoId, {
    HubModelFormat? expectedFormat,
  }) async {
    final files = await _fetchRepoFiles(repoId);

    final segments = repoId.split('/');
    return HubRepoDetail(
      summary: HubRepoSummary(
        source: source,
        format: expectedFormat ?? _formatFromFiles(files),
        repoId: repoId,
        owner: segments.length > 1 ? segments.first : '',
        name: segments.last,
        fileCount: files.length,
      ),
      files: files,
      revision: defaultRevision,
    );
  }

  Future<List<HubRepoFile>> _fetchRepoFiles(String repoId) async {
    final pendingRoots = <String>[''];
    final visitedRoots = <String>{};
    final filesByPath = <String, HubRepoFile>{};

    while (pendingRoots.isNotEmpty) {
      final root = pendingRoots.removeLast();
      if (!visitedRoots.add(root)) {
        continue;
      }
      final entries = await _fetchRepoEntries(repoId, root);
      for (final item in entries) {
        if (item is! Map) {
          continue;
        }
        final type = '${item['Type'] ?? ''}'.toLowerCase();
        final path = '${item['Path'] ?? item['Name'] ?? ''}'.trim();
        if (path.isEmpty) {
          continue;
        }
        if (type == 'tree') {
          pendingRoots.add(path);
          continue;
        }
        if (type != 'blob') {
          continue;
        }
        filesByPath[path] = HubRepoFile(
          path: path,
          sizeBytes: (item['Size'] as num?)?.toInt() ?? 0,
          sha256: item['Sha256'] as String?,
        );
      }
    }

    final files = filesByPath.values.toList(growable: false);
    files.sort((left, right) => left.path.compareTo(right.path));
    return files;
  }

  Future<List<dynamic>> _fetchRepoEntries(String repoId, String root) async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '$host/api/v1/models/$repoId/repo/files',
        queryParameters: <String, dynamic>{
          'Revision': defaultRevision,
          'Root': root,
        },
      );
    } on DioException catch (error) {
      throw ModelHubException(ModelHubErrorKind.network, detail: error.message);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const ModelHubException(ModelHubErrorKind.unauthorized);
    }
    if (response.statusCode == 404) {
      throw const ModelHubException(ModelHubErrorKind.notFound);
    }

    final entries = _dataOf(response)?['Files'];
    if (response.statusCode != 200 || entries is! List) {
      throw ModelHubException(
        ModelHubErrorKind.malformedResponse,
        detail: 'HTTP ${response.statusCode}',
      );
    }
    return entries;
  }

  @override
  String downloadUrl(String repoId, String filePath, {String? revision}) =>
      '$host/models/$repoId/resolve/${revision ?? defaultRevision}/$filePath';

  Map<String, dynamic>? _dataOf(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map) {
      return null;
    }
    final data = body['Data'];
    return data is Map ? Map<String, dynamic>.from(data) : null;
  }

  int? _modelScopeFileCount(Map<dynamic, dynamic> item) {
    for (final key in const <String>[
      'FilesCount',
      'FileCount',
      'FilesNum',
      'FileNum',
    ]) {
      final value = item[key];
      if (value is num && value >= 0) {
        return value.toInt();
      }
    }
    return null;
  }

  HubModelFormat _formatFromFiles(List<HubRepoFile> files) =>
      files.any((file) => file.isMnnModel)
      ? HubModelFormat.mnn
      : HubModelFormat.gguf;

  bool _hasModelScopeFormatEvidence(
    Map<dynamic, dynamic> item,
    List<String> tags,
    HubModelFormat format,
  ) {
    final labels = <String>{
      ...tags.map((tag) => tag.toLowerCase()),
      ...(item['Libraries'] as List? ?? const <dynamic>[])
          .whereType<String>()
          .map((library) => library.toLowerCase()),
      ...(item['OfficialTags'] as List? ?? const <dynamic>[])
          .whereType<String>()
          .map((tag) => tag.toLowerCase()),
    };
    return labels.contains(format.libraryTag);
  }
}
