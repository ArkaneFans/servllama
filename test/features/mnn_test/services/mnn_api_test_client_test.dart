import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/mnn_test/services/mnn_api_test_client.dart';

void main() {
  late HttpServer server;
  late MnnApiTestClient client;
  Map<String, dynamic>? receivedChatBody;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = MnnApiTestClient();
    server.listen((request) async {
      if (request.uri.path == '/health') {
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"status":"ready","engine":"mnn"}');
        await request.response.close();
        return;
      }
      if (request.uri.path == '/v1/chat/completions') {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        receivedChatBody = body as Map<String, dynamic>;
        if (body['stream'] == true) {
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          final messages = body['messages'] as List<dynamic>;
          final prompt = (messages.last as Map<String, dynamic>)['content'];
          if (prompt == 'fail') {
            request.response.write(
              'data: {"error":{"code":"generation_failed","message":"failed"}}\n\n',
            );
          } else {
            request.response.write(
              'data: {"choices":[{"delta":{"content":"Hello"}}]}\n\n',
            );
            request.response.write(
              'data: {"choices":[{"delta":{"content":" MNN"}}]}\n\n',
            );
          }
          request.response.write('data: [DONE]\n\n');
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            '{"choices":[{"message":{"content":"Hello MNN"}}],'
            '"usage":{"prompt_tokens":4,"completion_tokens":2,"total_tokens":6}}',
          );
        }
        await request.response.close();
        return;
      }
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    });
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('reads health JSON response', () async {
    final result = await client.getJson(
      baseUrl: 'http://127.0.0.1:${server.port}',
      path: '/health',
    );

    expect(result.succeeded, isTrue);
    expect(result.output, contains('"engine": "mnn"'));
    expect(result.statusCode, HttpStatus.ok);
    expect(result.elapsedMs, greaterThanOrEqualTo(0));
  });

  test('sends chat parameters and decodes usage', () async {
    final result = await client.chat(
      baseUrl: 'http://127.0.0.1:${server.port}',
      prompt: 'hello',
      systemPrompt: 'be concise',
      temperature: 0.3,
      topP: 0.8,
      maxTokens: 64,
    );

    expect(result.succeeded, isTrue);
    expect(result.promptTokens, 4);
    expect(result.completionTokens, 2);
    expect(result.totalTokens, 6);
    expect(receivedChatBody?['temperature'], 0.3);
    expect(receivedChatBody?['top_p'], 0.8);
    expect(receivedChatBody?['max_tokens'], 64);
    expect(receivedChatBody?['messages'], <Map<String, String>>[
      <String, String>{'role': 'system', 'content': 'be concise'},
      <String, String>{'role': 'user', 'content': 'hello'},
    ]);
  });

  test('decodes SSE chat deltas', () async {
    final chunks = <String>[];

    final result = await client.streamChat(
      baseUrl: 'http://127.0.0.1:${server.port}',
      prompt: 'hello',
      onChunk: chunks.add,
    );

    expect(result.succeeded, isTrue);
    expect(chunks, <String>['Hello', ' MNN']);
    expect(result.output, 'Hello MNN');
    expect(result.statusCode, HttpStatus.ok);
    expect(result.firstTokenMs, isNotNull);
  });

  test('surfaces OpenAI errors from an SSE stream', () async {
    final result = await client.streamChat(
      baseUrl: 'http://127.0.0.1:${server.port}',
      prompt: 'fail',
      onChunk: (_) {},
    );

    expect(result.succeeded, isFalse);
    expect(result.output, contains('generation_failed'));
  });
}
