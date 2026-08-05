import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/downloads/models/model_hub.dart';
import 'package:servllama/features/downloads/services/model_hub_client.dart';

void main() {
  group('HuggingFaceHubClient', () {
    test(
      'uses API filter=gguf instead of the ignored library parameter',
      () async {
        RequestOptions? captured;
        final client = HuggingFaceHubClient(
          dio: _stubDio((options) {
            captured = options;
            return _StubReply(
              data: <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'Qwen/Qwen3.5-4B',
                  'downloads': 1000,
                  'tags': <String>['transformers', 'safetensors'],
                  'siblings': <Map<String, dynamic>>[
                    <String, dynamic>{'rfilename': 'model.safetensors'},
                  ],
                },
                <String, dynamic>{
                  'id': 'owner/model-GGUF',
                  'downloads': 12,
                  'tags': <String>['gguf'],
                  'siblings': <Map<String, dynamic>>[
                    <String, dynamic>{'rfilename': 'model-q4.gguf'},
                  ],
                },
              ],
              headers: <String, List<String>>{
                'link': <String>[
                  '<https://huggingface.co/api/models?cursor=next%3Dtoken>; '
                      'rel="next"',
                ],
              },
            );
          }),
        );

        final results = await client.search(
          'qwen3.5',
          format: HubModelFormat.gguf,
          limit: 7,
        );

        expect(
          captured?.path,
          '${HuggingFaceHubClient.officialHost}/api/models',
        );
        expect(captured?.queryParameters['search'], 'qwen3.5');
        expect(captured?.queryParameters['filter'], 'gguf');
        expect(captured?.queryParameters.containsKey('library'), isFalse);
        expect(captured?.queryParameters['limit'], 7);
        expect(captured?.queryParameters['sort'], 'trendingScore');
        expect(results.items.single.format, HubModelFormat.gguf);
        expect(results.nextPageToken, 'next=token');
      },
    );

    test('omits an empty query and sends the opaque cursor', () async {
      RequestOptions? captured;
      final client = HuggingFaceHubClient(
        dio: _stubDio((options) {
          captured = options;
          return const <dynamic>[];
        }),
      );

      await client.search(
        '',
        format: HubModelFormat.gguf,
        pageToken: 'opaque+cursor=',
      );

      expect(captured?.queryParameters.containsKey('search'), isFalse);
      expect(captured?.queryParameters['cursor'], 'opaque+cursor=');
    });

    test('maps search sort to HF sort query values', () async {
      final sorts = <HubSearchSort, String>{
        HubSearchSort.trending: 'trendingScore',
        HubSearchSort.downloads: 'downloads',
        HubSearchSort.likes: 'likes',
      };
      for (final entry in sorts.entries) {
        RequestOptions? captured;
        final client = HuggingFaceHubClient(
          dio: _stubDio((options) {
            captured = options;
            return const <dynamic>[];
          }),
        );
        await client.search(
          'qwen',
          format: HubModelFormat.gguf,
          sort: entry.key,
        );
        expect(captured?.queryParameters['sort'], entry.value);
        expect(captured?.queryParameters['direction'], -1);
      }
    });

    test('does not issue unsupported MNN searches', () async {
      var requestCount = 0;
      final client = HuggingFaceHubClient(
        dio: _stubDio((_) {
          requestCount += 1;
          return const <dynamic>[];
        }),
      );

      final results = await client.search('qwen', format: HubModelFormat.mnn);

      expect(results.items, isEmpty);
      expect(requestCount, 0);
      expect(client.searchableFormats, <HubModelFormat>{HubModelFormat.gguf});
    });
  });

  group('ModelScopeHubClient', () {
    for (final format in HubModelFormat.values) {
      test('sends libraries=${format.name} in Criterion', () async {
        RequestOptions? captured;
        final client = ModelScopeHubClient(
          dio: _stubDio((options) {
            captured = options;
            return <String, dynamic>{
              'Data': <String, dynamic>{
                'Model': <String, dynamic>{
                  'Models': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'Path': 'owner',
                      'Name': 'model-${format.name}',
                      'Libraries': <String>[format.name],
                    },
                  ],
                  'TotalCount': 21,
                },
              },
            };
          }),
        );

        final results = await client.search('qwen3.5', format: format);

        final body = Map<String, dynamic>.from(captured?.data as Map);
        final criterion = (body['Criterion'] as List).single as Map;
        expect(captured?.method, 'PUT');
        expect(body['Name'], 'qwen3.5');
        expect(criterion['category'], 'libraries');
        expect(criterion['predicate'], 'contains');
        expect(criterion['values'], <String>[format.name]);
        expect(body['PageNumber'], 1);
        expect(body['SortBy'], 'Default');
        expect(results.items.single.format, format);
        expect(results.nextPageToken, '2');
      });
    }

    test('maps search sort to ModelScope SortBy values', () async {
      final sorts = <HubSearchSort, String>{
        HubSearchSort.trending: 'Default',
        HubSearchSort.downloads: 'DownloadsCount',
        HubSearchSort.likes: 'StarsCount',
      };
      for (final entry in sorts.entries) {
        RequestOptions? captured;
        final client = ModelScopeHubClient(
          dio: _stubDio((options) {
            captured = options;
            return <String, dynamic>{
              'Data': <String, dynamic>{
                'Model': <String, dynamic>{
                  'Models': <Map<String, dynamic>>[],
                  'TotalCount': 0,
                },
              },
            };
          }),
        );
        await client.search(
          'qwen',
          format: HubModelFormat.gguf,
          sort: entry.key,
        );
        final body = Map<String, dynamic>.from(captured?.data as Map);
        expect(body['SortBy'], entry.value);
      }
    });

    test('uses the page-number token for subsequent pages', () async {
      RequestOptions? captured;
      final client = ModelScopeHubClient(
        dio: _stubDio((options) {
          captured = options;
          return <String, dynamic>{
            'Data': <String, dynamic>{
              'Model': <String, dynamic>{
                'Models': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'Path': 'owner',
                    'Name': 'page-three',
                    'Libraries': <String>['gguf'],
                  },
                ],
                'TotalCount': 61,
              },
            },
          };
        }),
      );

      final page = await client.search(
        '',
        format: HubModelFormat.gguf,
        pageToken: '3',
      );

      final body = Map<String, dynamic>.from(captured?.data as Map);
      expect(body['Name'], '');
      expect(body['PageNumber'], 3);
      expect(page.nextPageToken, '4');
    });

    test('recursively includes files from tree entries', () async {
      final requestedRoots = <String>[];
      final client = ModelScopeHubClient(
        dio: _stubDio((options) {
          final root = '${options.queryParameters['Root'] ?? ''}';
          requestedRoots.add(root);
          final files = root.isEmpty
              ? <Map<String, dynamic>>[
                  <String, dynamic>{
                    'Type': 'tree',
                    'Name': 'llm',
                    'Path': 'llm',
                  },
                  <String, dynamic>{
                    'Type': 'blob',
                    'Name': 'config.json',
                    'Path': 'config.json',
                    'Size': 100,
                    'Sha256': 'root-sha',
                  },
                ]
              : <Map<String, dynamic>>[
                  <String, dynamic>{
                    'Type': 'blob',
                    'Name': 'llm.mnn',
                    'Path': 'llm/llm.mnn',
                    'Size': 200,
                    'Sha256': 'nested-sha',
                  },
                ];
          return <String, dynamic>{
            'Data': <String, dynamic>{'Files': files},
          };
        }),
      );

      final detail = await client.fetchRepo(
        'MNN/nested-model',
        expectedFormat: HubModelFormat.mnn,
      );

      expect(requestedRoots, <String>['', 'llm']);
      expect(detail.files.map((file) => file.path), <String>[
        'config.json',
        'llm/llm.mnn',
      ]);
      expect(detail.hasMnnModelFiles, isTrue);
      expect(detail.summary.format, HubModelFormat.mnn);
    });
  });
}

Dio _stubDio(dynamic Function(RequestOptions options) responder) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final value = responder(options);
        final reply = value is _StubReply ? value : _StubReply(data: value);
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            headers: Headers.fromMap(reply.headers),
            data: reply.data,
          ),
        );
      },
    ),
  );
  return dio;
}

class _StubReply {
  const _StubReply({
    required this.data,
    this.headers = const <String, List<String>>{},
  });

  final dynamic data;
  final Map<String, List<String>> headers;
}

