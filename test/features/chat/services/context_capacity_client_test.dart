import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/chat/services/context_capacity_client.dart';

void main() {
  group('parseLlamaCapacity', () {
    test('reads per-slot n_ctx without dividing by parallel slot count', () {
      expect(
        ContextCapacityClient.parseLlamaCapacity({
          'default_generation_settings': {'n_ctx': 4096},
          'total_slots': 4,
          'n_ctx': 16384,
        }),
        4096,
      );
    });

    test('accepts an integral JSON number', () {
      expect(
        ContextCapacityClient.parseLlamaCapacity({
          'default_generation_settings': {'n_ctx': 8192.0},
        }),
        8192,
      );
    });

    test('rejects missing, malformed and nonpositive capacity', () {
      for (final value in [
        null,
        '',
        [],
        {},
        {'n_ctx': 4096},
        {'default_generation_settings': []},
        {'default_generation_settings': {}},
        for (final count in [
          null,
          '4096',
          true,
          0,
          -4096,
          4096.5,
          double.nan,
          double.infinity,
          1e300,
        ])
          {
            'default_generation_settings': {'n_ctx': count},
          },
        {
          'default_generation_settings': {'max_new_tokens': 2048},
          'max_position_embeddings': 32768,
          'max_all_tokens': 2048,
        },
      ]) {
        expect(ContextCapacityClient.parseLlamaCapacity(value), isNull);
      }
    });
  });

  group('fetchLlamaCapacity', () {
    late Dio dio;
    late _Adapter adapter;
    late ContextCapacityClient client;

    setUp(() {
      dio = Dio();
      adapter = _Adapter();
      dio.httpClientAdapter = adapter;
      client = ContextCapacityClient(dio: dio);
    });
    tearDown(() => dio.close(force: true));

    test(
      'GETs props with optional auth and bounded nonredirecting options',
      () async {
        expect(
          await client.fetchLlamaCapacity(
            baseUrl: 'http://127.0.0.1:8080/',
            apiKey: ' local-key ',
          ),
          8192,
        );
        final request = adapter.requests.single;
        expect(request.uri.toString(), 'http://127.0.0.1:8080/props');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer local-key');
        expect(request.connectTimeout, const Duration(seconds: 3));
        expect(request.sendTimeout, const Duration(seconds: 3));
        expect(request.receiveTimeout, const Duration(seconds: 3));
        expect(request.followRedirects, isFalse);
        expect(request.maxRedirects, 0);
      },
    );

    test('does not send an empty credential', () async {
      await client.fetchLlamaCapacity(
        baseUrl: 'http://127.0.0.1:8080',
        apiKey: ' ',
      );
      expect(adapter.requests.single.headers, isNot(contains('Authorization')));
    });

    test(
      'returns unknown for non-200, redirect and malformed responses',
      () async {
        for (final status in [204, 301, 401, 404, 500, 503]) {
          adapter.status = status;
          expect(
            await client.fetchLlamaCapacity(
              baseUrl: 'http://127.0.0.1:8080',
              apiKey: '',
            ),
            isNull,
          );
        }
        adapter.status = 200;
        for (final body in ['{}', 'null', 'not json', '{"n_ctx":4096}']) {
          adapter.body = body;
          expect(
            await client.fetchLlamaCapacity(
              baseUrl: 'http://127.0.0.1:8080',
              apiKey: '',
            ),
            isNull,
          );
        }
      },
    );

    test('returns unknown on transport failure', () async {
      adapter.fail = true;
      expect(
        await client.fetchLlamaCapacity(
          baseUrl: 'http://127.0.0.1:8080',
          apiKey: '',
        ),
        isNull,
      );
    });
  });
}

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  String body =
      '{"default_generation_settings":{"n_ctx":8192},"total_slots":4}';
  bool fail = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (fail) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'fixture',
      );
    }
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
