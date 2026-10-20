import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';

void main() {
  for (final protocol in AiProtocol.values) {
    test(
      'discovers ${protocol.name} model candidates and handles its pagination',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final client = ChatProtocolClient();
        addTearDown(() async {
          client.dio.close(force: true);
          await server.close(force: true);
        });
        var requests = 0;
        server.listen((request) async {
          requests++;
          expect(request.uri.path, '/v1/models');
          final keyHeader = switch (protocol) {
            AiProtocol.openai => 'authorization',
            AiProtocol.anthropic => 'x-api-key',
            AiProtocol.gemini => 'x-goog-api-key',
          };
          expect(
            request.headers.value(keyHeader),
            protocol == AiProtocol.openai
                ? 'Bearer fixture-key'
                : 'fixture-key',
          );
          if (requests == 2) {
            expect(
              request.uri.queryParameters[protocol == AiProtocol.gemini
                  ? 'pageToken'
                  : 'after_id'],
              'next',
            );
          }
          final payload = switch (protocol) {
            AiProtocol.openai => {
              'data': [
                {'id': ' a '},
                {'id': 'a'},
                {'id': 'org/b'},
                {},
              ],
            },
            AiProtocol.anthropic => {
              'data': [
                {'id': requests == 1 ? 'a' : 'b'},
              ],
              'has_more': requests == 1,
              'last_id': 'next',
            },
            AiProtocol.gemini => {
              'models': [
                {'name': requests == 1 ? 'models/a' : 'models/b'},
              ],
              if (requests == 1) 'nextPageToken': 'next',
            },
          };
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(payload));
          await request.response.close();
        });
        final models = await client.listModels(
          AiConnection(
            id: 'p',
            name: 'P',
            protocol: protocol,
            baseUrl: 'http://127.0.0.1:${server.port}/v1',
          ),
          'fixture-key',
        );
        expect(
          models,
          protocol == AiProtocol.openai ? ['a', 'org/b'] : ['a', 'b'],
        );
        expect(requests, protocol == AiProtocol.openai ? 1 : 2);
      },
    );
  }

  test(
    'repeating cursors fail instead of returning an incomplete catalog',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = ChatProtocolClient();
      addTearDown(() async {
        client.dio.close(force: true);
        await server.close(force: true);
      });
      server.listen((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({'models': [], 'nextPageToken': 'same'}),
        );
        await request.response.close();
      });
      await expectLater(
        client.listModels(
          AiConnection(
            id: 'p',
            name: 'P',
            protocol: AiProtocol.gemini,
            baseUrl: 'http://127.0.0.1:${server.port}',
          ),
          '',
        ),
        throwsFormatException,
      );
    },
  );

  test('closing model discovery cancels the pending HTTP request', () async {
    final token = CancelToken()..cancel('closed');
    final client = ChatProtocolClient();
    addTearDown(() => client.dio.close(force: true));
    await expectLater(
      client.listModels(
        const AiConnection(
          id: 'p',
          name: 'P',
          protocol: AiProtocol.openai,
          baseUrl: 'http://127.0.0.1:1',
        ),
        '',
        cancelToken: token,
      ),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
  });
}
