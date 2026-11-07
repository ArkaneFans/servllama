import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/models/server_launch_settings.dart';
import 'package:servllama/core/services/server_launch_settings_loader.dart';
import 'package:servllama/features/assistants/models/assistant.dart';
import 'package:servllama/features/chat/models/generation_metrics.dart';
import 'package:servllama/features/chat/services/chat_protocol_client.dart';
import 'package:servllama/features/chat/services/llama_chat_api_client.dart';

class _Settings extends ServerLaunchSettingsLoader {
  @override
  Future<ServerLaunchSettings> load() async => const ServerLaunchSettings();
}

void main() {
  for (final legacy in [false, true]) {
    group(legacy ? 'legacy local HTTP' : 'protocol HTTP', () {
      late HttpServer server;
      late ChatProtocolClient protocol;
      late LlamaChatApiClient local;
      late Future<void> Function(HttpRequest, Map) handler;
      setUp(() async {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        protocol = ChatProtocolClient();
        local = LlamaChatApiClient(settingsLoader: _Settings())
          ..updateBaseUrl('http://127.0.0.1:${server.port}');
        server.listen((r) async {
          await handler(r, jsonDecode(await utf8.decodeStream(r)) as Map);
        });
      });
      tearDown(() async {
        protocol.dio.close(force: true);
        local.dio.close(force: true);
        await server.close(force: true);
      });
      Stream<GenerationMetrics?> request({
        String model = 'm',
        CancelToken? token,
      }) => legacy
          ? local
                .streamChatCompletion(
                  modelId: model,
                  messages: [],
                  cancelToken: token ?? CancelToken(),
                )
                .map((d) => d.generationMetrics)
          : protocol
                .complete(
                  AiConnection(
                    id: 'c',
                    name: 'c',
                    protocol: AiProtocol.openai,
                    baseUrl: 'http://127.0.0.1:${server.port}/v1',
                  ),
                  '',
                  model,
                  [],
                  cancelToken: token ?? CancelToken(),
                )
                .map((e) => e.generationMetrics);
      void emit(HttpRequest r, Map data) =>
          r.response.write('data: ${jsonEncode(data)}\n\n');
      void sse(HttpRequest r) => r.response.headers.contentType = ContentType(
        'text',
        'event-stream',
        charset: 'utf-8',
      );
      Future<void> done(HttpRequest r) async {
        r.response.write('data: [DONE]\n\n');
        await r.response.close();
      }

      test(
        'native SSE timing/usage-only tail survives and requests stay isolated',
        () async {
          handler = (r, body) async {
            sse(r);
            final n = body['model'] == 'a' ? 10 : 30;
            emit(r, {
              'id': body['model'],
              'choices': [
                {
                  'delta': {'content': '你好'},
                },
              ],
            });
            await r.response.flush();
            await Future<void>.delayed(Duration(milliseconds: n));
            emit(r, {
              'choices': [
                {'delta': {}, 'finish_reason': 'stop'},
              ],
            });
            emit(r, {
              'choices': [],
              'timings': {
                'prompt_n': n,
                'cache_n': 50,
                'prompt_ms': 100,
                'predicted_n': 10,
                'predicted_ms': 500,
              },
              'usage': {
                'prompt_tokens': n + 50,
                'completion_tokens': 10,
                'prompt_tokens_details': {'cached_tokens': 50},
              },
            });
            await done(r);
          };
          final results = await Future.wait([
            request(model: 'a').toList(),
            request(model: 'b').toList(),
          ]);
          final a = results[0].whereType<GenerationMetrics>().single;
          final b = results[1].whereType<GenerationMetrics>().single;
          expect(a.prefillTokensPerSecond, 100);
          expect(b.prefillTokensPerSecond, 300);
          expect(a.inputTokens, 60);
          expect(b.inputTokens, 80);
          expect(a.cachedInputTokens, 50);
          expect(a.prefillIsEstimated, isFalse);
          expect(a.decodeIsEstimated, isFalse);
        },
      );
      test(
        'reasoning is first output; missing timings use labelled usage estimates',
        () async {
          handler = (r, body) async {
            sse(r);
            await Future<void>.delayed(const Duration(milliseconds: 25));
            emit(r, {
              'choices': [
                {
                  'delta': {'reasoning_content': '思考'},
                },
              ],
            });
            r.response.write(': ${' ' * 16384}\n\n');
            await r.response.flush();
            await Future<void>.delayed(const Duration(milliseconds: 140));
            emit(r, {
              'choices': [
                {
                  'delta': {'content': '答案'},
                },
              ],
            });
            emit(r, {
              'choices': [
                {'delta': {}, 'finish_reason': 'stop'},
              ],
              'usage': {'prompt_tokens': 100, 'completion_tokens': 11},
            });
            await done(r);
          };
          final metrics = (await request().toList())
              .whereType<GenerationMetrics>()
              .single;
          expect(metrics.prefillIsEstimated, isTrue);
          expect(metrics.decodeIsEstimated, isTrue);
          expect(metrics.prefillTokensPerSecond, greaterThan(0));
          expect(metrics.predictedTokens, 10);
          expect(metrics.predictedMilliseconds, greaterThanOrEqualTo(100));
          expect(metrics.cachedInputTokens, isNull);
          expect(metrics.inputTokens, 100);
        },
      );
      test(
        'cumulative usage replaces earlier counters and survives later timing-only metadata',
        () async {
          handler = (r, body) async {
            sse(r);
            emit(r, {
              'choices': [
                {
                  'delta': {'content': 'answer'},
                },
              ],
            });
            for (final output in [10, 20, 20]) {
              emit(r, {
                'choices': [],
                'usage': {
                  'prompt_tokens': 100,
                  'completion_tokens': output,
                  'prompt_tokens_details': {'cached_tokens': 0},
                },
              });
            }
            emit(r, {
              'choices': [
                {'finish_reason': 'stop'},
              ],
              'timings': {'prompt_n': 100, 'prompt_ms': 200},
            });
            await done(r);
          };
          final metrics = (await request().toList())
              .whereType<GenerationMetrics>()
              .single;
          expect(metrics.inputTokens, 100);
          expect(metrics.outputTokens, 20);
          expect(metrics.cachedInputTokens, 0);
          expect(metrics.prefillTokensPerSecond, 500);
          expect(metrics.prefillIsEstimated, isFalse);
        },
      );
      test(
        'nonstream JSON keeps native timing and counts but cannot invent TTFT',
        () async {
          handler = (r, body) async {
            r.response.headers.contentType = ContentType.json;
            r.response.write(
              jsonEncode({
                'choices': [
                  {
                    'message': {'content': 'answer'},
                    'finish_reason': 'stop',
                  },
                ],
                'timings': {'prompt_n': 100, 'prompt_ms': 200},
                'usage': {
                  'prompt_tokens': 100,
                  'completion_tokens': 10,
                  'prompt_tokens_details': {'cached_tokens': 0},
                },
              }),
            );
            await r.response.close();
          };
          final metrics = (await request().toList())
              .whereType<GenerationMetrics>()
              .single;
          expect(metrics.prefillTokensPerSecond, 500);
          expect(metrics.decodeTokensPerSecond, isNull);
          expect(metrics.cachedInputTokens, 0);
          expect(metrics.outputTokens, 10);
          expect(metrics.prefillIsEstimated, isFalse);
        },
      );
      test('hosted MNN-like SSE without usage keeps statistics unknown', () async {
        handler = (r, body) async {
          sse(r);
          emit(r, {
            'choices': [
              {
                'delta': {'content': 'words are not tokens'},
              },
            ],
          });
          emit(r, {
            'choices': [
              {'finish_reason': 'stop'},
            ],
          });
          await done(r);
        };
        final metrics = (await request().toList())
            .whereType<GenerationMetrics>()
            .firstOrNull;
        expect(metrics?.inputTokens, isNull);
        expect(metrics?.outputTokens, isNull);
        expect(metrics?.prefillTokensPerSecond, isNull);
        expect(metrics?.decodeTokensPerSecond, isNull);
        expect(metrics?.cachedInputTokens, isNull);
        expect(metrics?.contextTokens, isNull);
        expect(metrics?.prefillIsEstimated ?? false, isFalse);
        expect(metrics?.decodeIsEstimated ?? false, isFalse);
      });
      test(
        'cancelled stream does not deliver terminal speed or counts',
        () async {
          final sent = Completer<void>();
          handler = (r, body) async {
            sse(r);
            emit(r, {
              'choices': [
                {
                  'delta': {'content': 'partial'},
                },
              ],
              'timings': {'prompt_n': 10, 'prompt_ms': 10},
              'usage': {'prompt_tokens': 10, 'completion_tokens': 2},
            });
            await r.response.flush();
            sent.complete();
          };
          final token = CancelToken();
          final seen = <GenerationMetrics?>[];
          final finished = request(token: token).forEach(seen.add).catchError((
            Object e,
          ) {
            expect(e, isA<DioException>());
          });
          await sent.future;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          token.cancel();
          await finished;
          expect(seen.whereType<GenerationMetrics>(), isEmpty);
        },
      );
    });
  }
  for (final provider in [AiProtocol.anthropic, AiProtocol.gemini]) {
    test(
      '${provider.name} tool-only output supports estimates and exact usage/cache semantics',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        final client = ChatProtocolClient();
        addTearDown(() => client.dio.close(force: true));
        server.listen((r) async {
          await r.drain<void>();
          r.response.headers.contentType = ContentType(
            'text',
            'event-stream',
            charset: 'utf-8',
          );
          void emit(Map data) =>
              r.response.write('data: ${jsonEncode(data)}\n\n');
          if (provider == AiProtocol.anthropic) {
            emit({
              'type': 'message_start',
              'message': {
                'usage': {
                  'input_tokens': 100,
                  'cache_read_input_tokens': 50,
                  'cache_creation_input_tokens': 20,
                },
              },
            });
            emit({
              'type': 'content_block_start',
              'index': 0,
              'content_block': {
                'type': 'tool_use',
                'id': 'tool',
                'name': 'clock',
                'input': {},
              },
            });
            emit({
              'type': 'content_block_delta',
              'index': 0,
              'delta': {'type': 'input_json_delta', 'partial_json': '{}'},
            });
          } else {
            emit({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'functionCall': {'name': 'clock', 'args': {}},
                      },
                    ],
                  },
                },
              ],
            });
          }
          r.response.write(': ${' ' * 16384}\n\n');
          await r.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 120));
          if (provider == AiProtocol.anthropic) {
            emit({
              'type': 'message_delta',
              'delta': {'stop_reason': 'tool_use'},
              'usage': {'output_tokens': 11},
            });
            emit({'type': 'message_stop'});
          } else {
            emit({
              'candidates': [
                {'finishReason': 'STOP'},
              ],
              'usageMetadata': {
                'promptTokenCount': 170,
                'cachedContentTokenCount': 50,
                'candidatesTokenCount': 8,
                'thoughtsTokenCount': 3,
              },
            });
          }
          await r.response.close();
        });
        final events = await client
            .complete(
              AiConnection(
                id: 'c',
                name: 'c',
                protocol: provider,
                baseUrl: 'http://127.0.0.1:${server.port}/v1',
              ),
              '',
              'model',
              [],
              cancelToken: CancelToken(),
            )
            .toList();
        final metrics = events.last.generationMetrics!;
        expect(events.last.calls, hasLength(1));
        expect(metrics.inputTokens, 170);
        expect(metrics.cachedInputTokens, 50);
        expect(metrics.outputTokens, 11);
        expect(metrics.prefillIsEstimated, isTrue);
        expect(metrics.decodeIsEstimated, isTrue);
        expect(metrics.predictedMilliseconds, greaterThan(80));
      },
    );
  }
}
