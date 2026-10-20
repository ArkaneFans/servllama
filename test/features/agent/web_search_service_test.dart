import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/features/agent/models/web_search.dart';
import 'package:servllama/features/agent/services/web_search_service.dart';

import 'web_search_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLogger logger;
  setUp(() => logger = AppLogger());
  tearDown(() => logger.dispose());

  Future<WebSearchResult> run(
    String html, {
    WebSearchProvider provider = WebSearchProvider.bing,
    int status = 200,
    int maxResults = 5,
    int? limit,
  }) async {
    final dio = searchTestDio((_, _) => searchHtml(html, status: status));
    addTearDown(dio.close);
    final service = WebSearchService(dio: dio, logger: logger);
    return service.search(
      'test query',
      options: WebSearchOptions(provider: provider, maxResults: maxResults),
      cancelToken: CancelToken(),
      limit: limit,
    );
  }

  test(
    'Bing unwraps source links, deduplicates and excludes unsafe URLs',
    () async {
      final encoded = base64Url.encode(
        utf8.encode('https://docs.example/guide#part'),
      );
      final result = await run('''
      <ol id="b_results">
      <li class="b_algo"><h2><a href="https://www.bing.com/ck/a?u=a1$encoded">A &amp; B</a></h2>
        <div class="b_caption"><p>  Two\n words. <script>hidden</script></p></div></li>
      <li class="b_algo"><h2><a href="https://docs.example/guide">Duplicate</a></h2></li>
      <li class="b_algo"><h2><a href="javascript:alert(1)">Unsafe</a></h2></li>
      <li class="b_algo"><h2><a href="https://user:secret@docs.example/">Credential URL</a></h2></li>
      <li class="b_algo"><h2><a href="https://www.bing.com/ck/a?u=broken">Broken redirect</a></h2></li>
      </ol>''');
      expect(result.items, hasLength(1));
      expect(result.items.single.url, 'https://docs.example/guide');
      expect(result.items.single.title, 'A & B');
      expect(result.items.single.snippet, 'Two words.');
    },
  );

  test(
    'DuckDuckGo unwraps uddg, ignores ads and keeps ordinary query strings',
    () async {
      final target = Uri.encodeComponent('https://docs.example/find?q=a%20b');
      final result = await run('''
      <div class="result result--ad"><a class="result__a" href="https://ad.example/">Ad</a></div>
      <div class="result"><a class="result__a" href="//duckduckgo.com/l/?uddg=$target">Documentation</a>
      <span class="result__snippet">Useful excerpt</span></div>
      <div class="result"><a class="result__a" href="https://other.example/?uddg=keep">Other source</a></div>
      ''', provider: WebSearchProvider.duckduckgo);
      expect(result.items.map((i) => i.url), [
        'https://docs.example/find?q=a%20b',
        'https://other.example/?uddg=keep',
      ]);
    },
  );

  test(
    'only the query goes to the selected provider and receipt metadata is bounded',
    () async {
      final requests = <RequestOptions>[];
      final dio = searchTestDio((request, _) {
        requests.add(request);
        return searchHtml(bingSearchFixture);
      });
      addTearDown(dio.close);
      final result = await WebSearchService(dio: dio, logger: logger).search(
        ' private & 中文 query ',
        options: const WebSearchOptions(maxResults: 2),
        cancelToken: CancelToken(),
        limit: 9,
        runId: 'run',
        callId: 'call',
      );
      expect(requests.single.uri.host, 'www.bing.com');
      expect(requests.single.uri.queryParameters, {'q': 'private & 中文 query'});
      expect(requests.single.data, isNull);
      expect(
        requests.single.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(result.toJson()['query'], 'private & 中文 query');
      final logs = logger
          .entriesFor(LogChannel.agent)
          .map((e) => e.message)
          .join('\n');
      expect(logs, contains('provider="bing"'));
      expect(logs, contains('limit=2'));
      for (final excluded in [
        'private',
        '中文',
        'docs.example',
        'documentation excerpt',
      ]) {
        expect(logs, isNot(contains(excluded)));
      }
    },
  );

  test(
    'limit and UTF-8 budget keep search results inside a complete tool receipt',
    () async {
      final rows = List.generate(
        10,
        (i) =>
            '<li class="b_algo"><h2><a href="https://docs.example/$i">${'标题😀' * 160}</a></h2><div class="b_caption"><p>${'文字😀' * 700}</p></div></li>',
      ).join();
      final limited = await run(rows, maxResults: 2, limit: 10);
      expect(limited.items, hasLength(2));
      final bounded = await run(rows, maxResults: 10);
      expect(utf8.encode(jsonEncode(bounded.toJson())).length, lessThan(16384));
      expect(bounded.items.length, lessThan(10));
      expect(bounded.items, isNotEmpty);
      expect(jsonDecode(jsonEncode(bounded.toJson())), isA<Map>());
    },
  );

  test(
    'recognized empty results are distinct from changed or blocked HTML',
    () async {
      expect((await run('<li class="b_no">No results</li>')).items, isEmpty);
      expect(
        (await run(
          '<div class="no-results">No results</div>',
          provider: WebSearchProvider.duckduckgo,
        )).items,
        isEmpty,
      );
      await expectLater(
        run('<html>Changed page</html>'),
        throwsA(
          isA<WebSearchException>().having(
            (e) => e.reason,
            'reason',
            WebSearchFailure.invalidResponse,
          ),
        ),
      );
      await expectLater(
        run('<form id="challenge-form"></form>'),
        throwsA(
          isA<WebSearchException>().having(
            (e) => e.reason,
            'reason',
            WebSearchFailure.challenge,
          ),
        ),
      );
      await expectLater(
        run('challenge', status: 202),
        throwsA(
          isA<WebSearchException>().having(
            (e) => e.reason,
            'reason',
            WebSearchFailure.challenge,
          ),
        ),
      );
      await expectLater(
        run('query or secret in provider error', status: 429),
        throwsA(
          isA<WebSearchException>()
              .having((e) => e.reason, 'reason', WebSearchFailure.rateLimited)
              .having(
                (e) => e.toString(),
                'safe message',
                isNot(contains('secret')),
              ),
        ),
      );
    },
  );

  test('redirects remain inside the selected provider', () async {
    final requests = <Uri>[];
    var external = false;
    final dio = searchTestDio((request, _) {
      requests.add(request.uri);
      if (request.uri.host == 'cn.bing.com') {
        return searchHtml(bingSearchFixture);
      }
      return searchHtml(
        '',
        status: 302,
        headers: {
          'location': [
            external
                ? 'https://unrelated.example/search'
                : 'https://cn.bing.com/search?q=test',
          ],
        },
      );
    });
    addTearDown(dio.close);
    final service = WebSearchService(dio: dio, logger: logger);
    await service.search(
      'test',
      options: const WebSearchOptions(),
      cancelToken: CancelToken(),
    );
    expect(requests.map((u) => u.host), ['www.bing.com', 'cn.bing.com']);
    external = true;
    requests.clear();
    await expectLater(
      service.search(
        'test',
        options: const WebSearchOptions(),
        cancelToken: CancelToken(),
      ),
      throwsA(isA<WebSearchException>()),
    );
    expect(requests.map((u) => u.host), ['www.bing.com']);
  });

  test('response byte limit applies even without Content-Length', () async {
    await expectLater(
      run('x' * (WebSearchService.maxResponseBytes + 1)),
      throwsA(
        isA<WebSearchException>().having(
          (e) => e.reason,
          'reason',
          WebSearchFailure.tooLarge,
        ),
      ),
    );
  });

  test(
    'cancel interrupts a pending HTTP request without retaining query text',
    () async {
      final started = Completer<void>(), aborted = Completer<void>();
      final dio = searchTestDio((request, cancelled) async {
        started.complete();
        await cancelled;
        aborted.complete();
        throw DioException(
          requestOptions: request,
          type: DioExceptionType.cancel,
        );
      });
      addTearDown(dio.close);
      final token = CancelToken();
      final result = WebSearchService(dio: dio, logger: logger).search(
        'private query',
        options: const WebSearchOptions(),
        cancelToken: token,
      );
      final expectation = expectLater(
        result,
        throwsA(
          isA<DioException>().having(
            (e) => e.type,
            'type',
            DioExceptionType.cancel,
          ),
        ),
      );
      await started.future;
      token.cancel('stopped');
      await expectation;
      await aborted.future;
      expect(
        logger.entriesFor(LogChannel.agent).last.message,
        contains('outcome="cancelled"'),
      );
    },
  );

  test(
    'total timeout cancels a stalled body but leaves the chat token usable',
    () async {
      final bodyCancelled = Completer<void>();
      final controller = StreamController<Uint8List>(
        onCancel: bodyCancelled.complete,
      );
      final dio = searchTestDio((_, _) => ResponseBody(controller.stream, 200));
      addTearDown(dio.close);
      addTearDown(controller.close);
      final token = CancelToken();
      await expectLater(
        WebSearchService(
          dio: dio,
          logger: logger,
          timeout: const Duration(milliseconds: 60),
        ).search('test', options: const WebSearchOptions(), cancelToken: token),
        throwsA(
          isA<WebSearchException>().having(
            (e) => e.reason,
            'reason',
            WebSearchFailure.timeout,
          ),
        ),
      );
      await bodyCancelled.future.timeout(const Duration(seconds: 2));
      expect(token.isCancelled, isFalse);
    },
  );

  test('empty queries fail before making a request', () async {
    var calls = 0;
    final dio = searchTestDio((_, _) {
      calls++;
      return searchHtml(bingSearchFixture);
    });
    addTearDown(dio.close);
    await expectLater(
      WebSearchService(dio: dio, logger: logger).search(
        '  ',
        options: const WebSearchOptions(),
        cancelToken: CancelToken(),
      ),
      throwsFormatException,
    );
    expect(calls, 0);
  });
}
