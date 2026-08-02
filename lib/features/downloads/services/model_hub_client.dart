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

  Future<List<HubRepoSummary>> search(String query, {int limit = 20});

  Future<HubRepoDetail> fetchRepo(String repoId);

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
  Map<String, String> authHeaders(String? token) {
    final trimmed = token?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $trimmed'};
  }

  @override
  Future<List<HubRepoSummary>> search(String query, {int limit = 20}) async {
    final response = await _get<List<dynamic>>(
      '$_host/api/models',
      queryParameters: <String, dynamic>{
        'search': query,
        'filter': 'gguf',
        'limit': limit,
        'sort': 'downloads',
        'direction': -1,
        // The full response includes `siblings`, which lets the result card
        // show a file count without opening every repository individually.
        'full': true,
      },
    );

    final results = <HubRepoSummary>[];
    for (final item in response) {
      if (item is! Map) {
        continue;
      }
      final repoId = '${item['id'] ?? item['modelId'] ?? ''}'.trim();
      if (repoId.isEmpty) {
        continue;
      }
      final segments = repoId.split('/');
      results.add(
        HubRepoSummary(
          source: source,
          repoId: repoId,
          owner: segments.length > 1 ? segments.first : '',
          name: segments.last,
          downloads: (item['downloads'] as num?)?.toInt() ?? 0,
          likes: (item['likes'] as num?)?.toInt() ?? 0,
          lastModified: DateTime.tryParse('${item['lastModified'] ?? ''}'),
          fileCount: item['siblings'] is List
              ? (item['siblings'] as List).length
              : null,
          tags:
              (item['tags'] as List?)?.whereType<String>().toList(
                growable: false,
              ) ??
              const <String>[],
        ),
      );
    }
    return results;
  }

  @override
  Future<HubRepoDetail> fetchRepo(String repoId) async {
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
    final data = response.data;
    if (response.statusCode != 200 || data is! T) {
      throw ModelHubException(
        ModelHubErrorKind.malformedResponse,
        detail: 'HTTP ${response.statusCode}',
      );
    }
    return data;
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
  Map<String, String> authHeaders(String? token) {
    final trimmed = token?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const <String, String>{};
    }
    return <String, String>{'Authorization': 'Bearer $trimmed'};
  }

  @override
  Future<List<HubRepoSummary>> search(String query, {int limit = 20}) async {
    final Response<dynamic> response;
    try {
      response = await _dio.put<dynamic>(
        '$host/api/v1/dolphin/models',
        data: <String, dynamic>{
          'PageSize': limit,
          'PageNumber': 1,
          'SortBy': 'Default',
          'Target': '',
          'SingleCriterion': <dynamic>[],
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
      return const <HubRepoSummary>[];
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
      final updatedSeconds = (item['LastUpdatedTime'] as num?)?.toInt();
      results.add(
        HubRepoSummary(
          source: source,
          repoId: '$owner/$name',
          owner: owner,
          name: name,
          downloads: (item['Downloads'] as num?)?.toInt() ?? 0,
          likes: (item['Stars'] as num?)?.toInt() ?? 0,
          lastModified: updatedSeconds == null || updatedSeconds <= 0
              ? null
              : DateTime.fromMillisecondsSinceEpoch(updatedSeconds * 1000),
          fileCount: _modelScopeFileCount(item),
          tags:
              (item['Tags'] as List?)?.whereType<String>().toList(
                growable: false,
              ) ??
              const <String>[],
        ),
      );
    }
    return results;
  }

  @override
  Future<HubRepoDetail> fetchRepo(String repoId) async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        '$host/api/v1/models/$repoId/repo/files',
        queryParameters: <String, dynamic>{
          'Revision': defaultRevision,
          'Root': '',
        },
      );
    } on DioException catch (error) {
      throw ModelHubException(ModelHubErrorKind.network, detail: error.message);
    }
    if (response.statusCode == 404) {
      throw const ModelHubException(ModelHubErrorKind.notFound);
    }

    final entries = _dataOf(response)?['Files'];
    if (entries is! List) {
      throw const ModelHubException(ModelHubErrorKind.malformedResponse);
    }

    final files = <HubRepoFile>[];
    for (final item in entries) {
      if (item is! Map || item['Type'] != 'blob') {
        continue;
      }
      final path = '${item['Path'] ?? item['Name'] ?? ''}'.trim();
      if (path.isEmpty) {
        continue;
      }
      files.add(
        HubRepoFile(
          path: path,
          sizeBytes: (item['Size'] as num?)?.toInt() ?? 0,
          sha256: item['Sha256'] as String?,
        ),
      );
    }

    final segments = repoId.split('/');
    return HubRepoDetail(
      summary: HubRepoSummary(
        source: source,
        repoId: repoId,
        owner: segments.length > 1 ? segments.first : '',
        name: segments.last,
        fileCount: files.length,
      ),
      files: files,
      revision: defaultRevision,
    );
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
}
