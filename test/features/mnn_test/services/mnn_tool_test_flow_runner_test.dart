import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/features/mnn_test/models/mnn_api_test_result.dart';
import 'package:servllama/features/mnn_test/services/mnn_api_test_client.dart';
import 'package:servllama/features/mnn_test/services/mnn_tool_test_flow_runner.dart';

void main() {
  late HttpServer server;
  late MnnApiTestClient client;
  late MnnToolTestFlowRunner runner;
  final receivedBodies = <Map<String, dynamic>>[];
  var responseMode = _ResponseMode.success;

  setUp(() async {
    receivedBodies.clear();
    responseMode = _ResponseMode.success;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    client = MnnApiTestClient();
    runner = MnnToolTestFlowRunner(apiClient: client);
    server.listen((request) async {
      if (request.uri.path != '/v1/chat/completions') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      receivedBodies.add(Map<String, dynamic>.from(body as Map));
      request.response.headers.contentType = ContentType.json;
      final isFollowup = receivedBodies.length > 1;
      final response = switch (responseMode) {
        _ResponseMode.success when !isFollowup => _toolCallResponse(),
        _ResponseMode.success => _finalResponse(),
        _ResponseMode.invalidToolCall => _invalidToolCallResponse(),
        _ResponseMode.toolExecutionFailure => _toolCallResponse(city: '北京'),
        _ResponseMode.invalidFinalAnswer => _invalidFinalAnswerResponse(),
        _ResponseMode.additionalToolCall => _toolCallResponse(),
        _ResponseMode.httpFailure => <String, Object?>{
          'error': <String, Object?>{'code': 'test_failure', 'message': '模拟失败'},
        },
      };
      if (responseMode == _ResponseMode.httpFailure ||
          (responseMode == _ResponseMode.invalidFinalAnswer && isFollowup)) {
        request.response.statusCode = HttpStatus.badRequest;
      }
      request.response.write(jsonEncode(response));
      await request.response.close();
    });
  });

  tearDown(() async {
    client.close();
    await server.close(force: true);
  });

  test('runs the complete tool flow and preserves tool history', () async {
    final progress = <List<MnnApiTestStep>>[];
    final result = await runner.run(
      baseUrl: 'http://127.0.0.1:${server.port}',
      model: 'local/qwen-test',
      onProgress: (steps) => progress.add(steps),
    );

    expect(result.succeeded, isTrue);
    expect(result.exchanges, hasLength(2));
    expect(result.steps, hasLength(7));
    expect(
      result.steps,
      everyElement(
        predicate<MnnApiTestStep>(
          (step) => step.status == MnnApiTestStepStatus.succeeded,
        ),
      ),
    );
    expect(result.steps[2].checks, hasLength(12));
    expect(progress, isNotEmpty);
    expect(receivedBodies, hasLength(2));
    final followupMessages = receivedBodies[1]['messages'] as List<dynamic>;
    expect((followupMessages[1] as Map)['role'], 'assistant');
    expect((followupMessages[2] as Map)['role'], 'tool');
    expect((followupMessages[2] as Map)['tool_call_id'], 'call_test_1');
    expect(
      MnnApiTestClient.asJsonMap((followupMessages[2] as Map)['content']),
      containsPair('timezone', 'Asia/Shanghai'),
    );
  });

  test(
    'does not execute or continue when tool-call format is invalid',
    () async {
      responseMode = _ResponseMode.invalidToolCall;

      final result = await runner.run(
        baseUrl: 'http://127.0.0.1:${server.port}',
      );

      expect(result.succeeded, isFalse);
      expect(result.steps[2].status, MnnApiTestStepStatus.failed);
      expect(
        result.steps.skip(3),
        everyElement(
          predicate<MnnApiTestStep>(
            (step) => step.status == MnnApiTestStepStatus.skipped,
          ),
        ),
      );
      expect(receivedBodies, hasLength(1));
      expect(result.steps[2].checks, isNotEmpty);
      expect(result.steps[2].checks.any((check) => !check.succeeded), isTrue);
    },
  );

  test('marks local tool execution failure and skips follow-up', () async {
    responseMode = _ResponseMode.toolExecutionFailure;

    final result = await runner.run(baseUrl: 'http://127.0.0.1:${server.port}');

    expect(result.succeeded, isFalse);
    expect(result.steps[2].status, MnnApiTestStepStatus.succeeded);
    expect(result.steps[3].status, MnnApiTestStepStatus.failed);
    expect(result.steps[3].error, contains('只支持城市'));
    expect(result.steps[4].status, MnnApiTestStepStatus.skipped);
    expect(receivedBodies, hasLength(1));
  });

  test('marks a failed final request without entering a tool loop', () async {
    responseMode = _ResponseMode.invalidFinalAnswer;

    final result = await runner.run(baseUrl: 'http://127.0.0.1:${server.port}');

    expect(result.succeeded, isFalse);
    expect(receivedBodies, hasLength(2));
    expect(result.steps[5].status, MnnApiTestStepStatus.failed);
    expect(result.steps[6].status, MnnApiTestStepStatus.skipped);
  });

  test('rejects an additional tool call instead of entering a loop', () async {
    responseMode = _ResponseMode.additionalToolCall;

    final result = await runner.run(baseUrl: 'http://127.0.0.1:${server.port}');

    expect(result.succeeded, isFalse);
    expect(receivedBodies, hasLength(2));
    expect(result.steps[5].status, MnnApiTestStepStatus.succeeded);
    expect(result.steps[6].status, MnnApiTestStepStatus.failed);
    expect(result.steps[6].error, 'unexpected_additional_tool_call');
  });
}

enum _ResponseMode {
  success,
  invalidToolCall,
  toolExecutionFailure,
  invalidFinalAnswer,
  additionalToolCall,
  httpFailure,
}

Map<String, Object?> _toolCallResponse({String city = '上海'}) {
  return <String, Object?>{
    'id': 'chatcmpl-tool-test',
    'choices': <Object?>[
      <String, Object?>{
        'finish_reason': 'tool_calls',
        'message': <String, Object?>{
          'role': 'assistant',
          'content': null,
          'tool_calls': <Object?>[
            <String, Object?>{
              'id': 'call_test_1',
              'type': 'function',
              'function': <String, Object?>{
                'name': MnnApiTestClient.toolName,
                'arguments': jsonEncode(<String, String>{'city': city}),
              },
            },
          ],
        },
      },
    ],
  };
}

Map<String, Object?> _finalResponse() {
  return <String, Object?>{
    'id': 'chatcmpl-final-test',
    'choices': <Object?>[
      <String, Object?>{
        'finish_reason': 'stop',
        'message': <String, Object?>{
          'role': 'assistant',
          'content': '上海当前时间已经查询完成。',
        },
      },
    ],
  };
}

Map<String, Object?> _invalidToolCallResponse() {
  final response = _toolCallResponse();
  final choices = response['choices'] as List<Object?>;
  final choice = choices.first as Map<String, Object?>;
  final message = choice['message'] as Map<String, Object?>;
  final calls = message['tool_calls'] as List<Object?>;
  final call = calls.first as Map<String, Object?>;
  final function = call['function'] as Map<String, Object?>;
  function['arguments'] = '{not-json';
  return response;
}

Map<String, Object?> _invalidFinalAnswerResponse() {
  return _toolCallResponse();
}
