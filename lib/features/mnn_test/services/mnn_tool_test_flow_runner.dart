import 'dart:convert';

import 'package:servllama/features/mnn_test/models/mnn_api_test_result.dart';
import 'package:servllama/features/mnn_test/services/mnn_api_test_client.dart';

typedef MnnToolFlowProgress = void Function(List<MnnApiTestStep> steps);

class MnnToolTestFlowRunner {
  MnnToolTestFlowRunner({required MnnApiTestClient apiClient})
    : _apiClient = apiClient;

  final MnnApiTestClient _apiClient;

  Future<MnnApiTestResult> run({
    required String baseUrl,
    String? model,
    String? apiKey,
    int maxTokens = 512,
    MnnToolFlowProgress? onProgress,
  }) async {
    final started = Stopwatch()..start();
    final steps = <MnnApiTestStep>[
      const MnnApiTestStep(
        id: 'prepare_initial_request',
        title: '构建首次请求',
        status: MnnApiTestStepStatus.pending,
      ),
      const MnnApiTestStep(
        id: 'request_tool_call',
        title: '请求 LLM 工具调用',
        status: MnnApiTestStepStatus.pending,
      ),
      const MnnApiTestStep(
        id: 'validate_tool_call',
        title: '校验工具调用格式',
        status: MnnApiTestStepStatus.pending,
      ),
      const MnnApiTestStep(
        id: 'execute_tool',
        title: '执行本地测试工具',
        status: MnnApiTestStepStatus.pending,
      ),
      const MnnApiTestStep(
        id: 'prepare_followup_request',
        title: '构建工具结果续答请求',
        status: MnnApiTestStepStatus.pending,
      ),
      const MnnApiTestStep(
        id: 'request_final_answer',
        title: '请求 LLM 最终回答',
        status: MnnApiTestStepStatus.pending,
      ),
      const MnnApiTestStep(
        id: 'validate_final_answer',
        title: '校验最终回答',
        status: MnnApiTestStepStatus.pending,
      ),
    ];
    final stepTimers = <int, Stopwatch>{};

    void emit() => onProgress?.call(List<MnnApiTestStep>.unmodifiable(steps));
    void setStep(int index, MnnApiTestStep step) {
      final timer = stepTimers[index];
      steps[index] = timer == null
          ? step
          : step.copyWith(elapsedMs: timer.elapsedMilliseconds);
      emit();
    }

    void running(int index) {
      stepTimers[index] = Stopwatch()..start();
      setStep(
        index,
        steps[index].copyWith(status: MnnApiTestStepStatus.running),
      );
    }

    void fail(int index, String message) {
      setStep(
        index,
        steps[index].copyWith(
          status: MnnApiTestStepStatus.failed,
          error: message,
        ),
      );
      for (var i = index + 1; i < steps.length; i++) {
        if (steps[i].status == MnnApiTestStepStatus.pending) {
          steps[i] = steps[i].copyWith(
            status: MnnApiTestStepStatus.skipped,
            error: 'blocked_by_previous_step',
          );
        }
      }
      emit();
    }

    final initialBody = <String, Object?>{
      'model': model,
      'messages': <Map<String, Object?>>[
        <String, Object?>{
          'role': 'user',
          'content': MnnApiTestClient.toolPrompt,
        },
      ],
      'tools': <Map<String, Object?>>[MnnApiTestClient.timeTool],
      'tool_choice': 'required',
      'parallel_tool_calls': false,
      'stream': false,
      'max_tokens': maxTokens,
    };
    final initialUrl = '$baseUrl/v1/chat/completions';
    final initialDisplay = _apiClient.displayRequest(
      method: 'POST',
      url: initialUrl,
      headers: _headers(apiKey),
      body: initialBody,
    );

    running(0);
    final initialChecks = _validateInitialRequest(initialBody);
    final initialValid = initialChecks.every((check) => check.succeeded);
    setStep(
      0,
      steps[0].copyWith(
        status: initialValid
            ? MnnApiTestStepStatus.succeeded
            : MnnApiTestStepStatus.failed,
        checks: initialChecks,
        input: initialDisplay,
        output: _checksText(initialChecks),
        error: initialValid ? null : '首次请求格式校验失败',
      ),
    );
    if (!initialValid) {
      fail(0, '首次请求格式校验失败');
      return _result(
        steps: steps,
        exchanges: const <MnnApiExchange>[],
        elapsedMs: started.elapsedMilliseconds,
        output: _flowOutput(steps),
      );
    }

    running(1);
    final first = await _apiClient.postJson(
      baseUrl: baseUrl,
      path: '/v1/chat/completions',
      body: initialBody,
      apiKey: apiKey,
    );
    setStep(
      1,
      steps[1].copyWith(
        status: first.succeeded
            ? MnnApiTestStepStatus.succeeded
            : MnnApiTestStepStatus.failed,
        exchange: first.exchange,
        output: first.exchange.responseDisplay,
        error: first.exchange.errorMessage,
      ),
    );
    if (!first.succeeded) {
      fail(1, first.exchange.errorMessage ?? '首次工具请求失败');
      return _result(
        steps: steps,
        exchanges: <MnnApiExchange>[first.exchange],
        elapsedMs: started.elapsedMilliseconds,
        output: _flowOutput(steps),
      );
    }

    running(2);
    final validation = _validateToolCall(first.responseData);
    setStep(
      2,
      steps[2].copyWith(
        status: validation.succeeded
            ? MnnApiTestStepStatus.succeeded
            : MnnApiTestStepStatus.failed,
        checks: validation.checks,
        output: _checksText(validation.checks),
        error: validation.error,
      ),
    );
    if (!validation.succeeded || validation.call == null) {
      fail(2, validation.error ?? '工具调用格式校验失败');
      return _result(
        steps: steps,
        exchanges: <MnnApiExchange>[first.exchange],
        elapsedMs: started.elapsedMilliseconds,
        output: _flowOutput(steps),
        toolArguments: validation.argumentsText,
      );
    }

    running(3);
    final toolInput = validation.arguments!;
    late final Map<String, Object?> toolOutput;
    late final String toolOutputJson;
    try {
      toolOutput = _executeTool(toolInput);
      toolOutputJson = jsonEncode(toolOutput);
    } catch (error) {
      setStep(
        3,
        steps[3].copyWith(
          status: MnnApiTestStepStatus.failed,
          input: MnnApiTestClient.pretty(toolInput),
          error: error.toString(),
        ),
      );
      fail(3, error.toString());
      return _result(
        steps: steps,
        exchanges: <MnnApiExchange>[first.exchange],
        elapsedMs: started.elapsedMilliseconds,
        output: _flowOutput(steps),
        toolCallId: validation.call!.id,
        toolName: validation.call!.name,
        toolArguments: validation.argumentsText,
      );
    }
    setStep(
      3,
      steps[3].copyWith(
        status: MnnApiTestStepStatus.succeeded,
        input: MnnApiTestClient.pretty(toolInput),
        output: MnnApiTestClient.pretty(toolOutput),
      ),
    );

    final assistantMessage = validation.call!.assistantMessage;
    final followupBody = <String, Object?>{
      'model': model,
      'messages': <Object?>[
        <String, Object?>{
          'role': 'user',
          'content': MnnApiTestClient.toolPrompt,
        },
        assistantMessage,
        <String, Object?>{
          'role': 'tool',
          'tool_call_id': validation.call!.id,
          'content': toolOutputJson,
        },
      ],
      'tools': <Map<String, Object?>>[MnnApiTestClient.timeTool],
      'tool_choice': 'none',
      'parallel_tool_calls': false,
      'stream': false,
      'max_tokens': maxTokens,
    };
    final followupDisplay = _apiClient.displayRequest(
      method: 'POST',
      url: initialUrl,
      headers: _headers(apiKey),
      body: followupBody,
    );
    running(4);
    final followupChecks = _validateFollowupRequest(
      followupBody,
      expectedToolCallId: validation.call!.id,
    );
    final followupValid = followupChecks.every((check) => check.succeeded);
    setStep(
      4,
      steps[4].copyWith(
        status: followupValid
            ? MnnApiTestStepStatus.succeeded
            : MnnApiTestStepStatus.failed,
        checks: followupChecks,
        input: followupDisplay,
        output: _checksText(followupChecks),
        error: followupValid ? null : '工具结果续答请求格式校验失败',
      ),
    );
    if (!followupValid) {
      fail(4, '工具结果续答请求格式校验失败');
      return _result(
        steps: steps,
        exchanges: <MnnApiExchange>[first.exchange],
        elapsedMs: started.elapsedMilliseconds,
        output: _flowOutput(steps),
        toolCallId: validation.call!.id,
        toolName: validation.call!.name,
        toolArguments: validation.argumentsText,
      );
    }

    running(5);
    final second = await _apiClient.postJson(
      baseUrl: baseUrl,
      path: '/v1/chat/completions',
      body: followupBody,
      apiKey: apiKey,
    );
    setStep(
      5,
      steps[5].copyWith(
        status: second.succeeded
            ? MnnApiTestStepStatus.succeeded
            : MnnApiTestStepStatus.failed,
        exchange: second.exchange,
        output: second.exchange.responseDisplay,
        error: second.exchange.errorMessage,
      ),
    );
    if (!second.succeeded) {
      fail(5, second.exchange.errorMessage ?? '最终回答请求失败');
      return _result(
        steps: steps,
        exchanges: <MnnApiExchange>[first.exchange, second.exchange],
        elapsedMs: started.elapsedMilliseconds,
        output: _flowOutput(steps),
        toolCallId: validation.call!.id,
        toolName: validation.call!.name,
        toolArguments: validation.argumentsText,
      );
    }

    running(6);
    final finalValidation = _validateFinalAnswer(second.responseData);
    setStep(
      6,
      steps[6].copyWith(
        status: finalValidation.succeeded
            ? MnnApiTestStepStatus.succeeded
            : MnnApiTestStepStatus.failed,
        checks: finalValidation.checks,
        output: _checksText(finalValidation.checks),
        error: finalValidation.error,
      ),
    );
    if (!finalValidation.succeeded) {
      fail(6, finalValidation.error ?? '最终回答格式校验失败');
    }
    return _result(
      steps: steps,
      exchanges: <MnnApiExchange>[first.exchange, second.exchange],
      elapsedMs: started.elapsedMilliseconds,
      output: _flowOutput(steps),
      toolCallId: validation.call!.id,
      toolName: validation.call!.name,
      toolArguments: validation.argumentsText,
      succeeded: finalValidation.succeeded,
    );
  }

  List<MnnApiValidationCheck> _validateInitialRequest(
    Map<String, Object?> body,
  ) {
    final messages = body['messages'];
    final tools = body['tools'];
    final tool = tools is List && tools.isNotEmpty ? tools.first : null;
    final function = tool is Map ? tool['function'] : null;
    final parameters = function is Map ? function['parameters'] : null;
    final required = parameters is Map ? parameters['required'] : null;
    return <MnnApiValidationCheck>[
      MnnApiValidationCheck(
        id: 'prompt',
        label: '中文 Prompt 非空',
        succeeded:
            messages is List &&
            messages.isNotEmpty &&
            messages.first is Map &&
            (messages.first as Map)['content'] is String &&
            ((messages.first as Map)['content'] as String).trim().isNotEmpty,
      ),
      MnnApiValidationCheck(
        id: 'message_count',
        label: '首次请求只包含一条 user 消息',
        succeeded:
            messages is List &&
            messages.length == 1 &&
            messages.first is Map &&
            (messages.first as Map)['role'] == 'user',
      ),
      MnnApiValidationCheck(
        id: 'tools',
        label: 'tools 为非空数组',
        succeeded: tools is List && tools.length == 1,
      ),
      MnnApiValidationCheck(
        id: 'function_name',
        label: 'function name 符合协议',
        succeeded:
            function is Map && function['name'] == MnnApiTestClient.toolName,
      ),
      MnnApiValidationCheck(
        id: 'tool_type',
        label: 'tool type=function',
        succeeded: tool is Map && tool['type'] == 'function',
      ),
      MnnApiValidationCheck(
        id: 'parameters_object',
        label: 'parameters 为 JSON object',
        succeeded: parameters is Map && parameters['type'] == 'object',
      ),
      MnnApiValidationCheck(
        id: 'required_city',
        label: 'required 包含 city',
        succeeded: required is List && required.contains('city'),
      ),
      MnnApiValidationCheck(
        id: 'tool_choice',
        label: 'tool_choice=require',
        succeeded: body['tool_choice'] == 'required',
      ),
      MnnApiValidationCheck(
        id: 'parallel_tool_calls',
        label: 'parallel_tool_calls=false',
        succeeded: body['parallel_tool_calls'] == false,
      ),
      MnnApiValidationCheck(
        id: 'stream',
        label: '首次请求使用完整 JSON（stream=false）',
        succeeded: body['stream'] == false,
      ),
    ];
  }

  _ToolValidation _validateToolCall(Object? response) {
    final root = MnnApiTestClient.asJsonMap(response);
    final choices = root?['choices'];
    final choice = choices is List && choices.isNotEmpty ? choices.first : null;
    final choiceMap = choice is Map ? choice : null;
    final message = choiceMap?['message'];
    final messageMap = message is Map
        ? Map<String, dynamic>.from(message)
        : null;
    final calls = messageMap?['tool_calls'];
    final call = calls is List && calls.isNotEmpty ? calls.first : null;
    final callMap = call is Map ? call : null;
    final function = callMap?['function'];
    final functionMap = function is Map ? function : null;
    final id = callMap?['id'];
    final type = callMap?['type'];
    final name = functionMap?['name'];
    final arguments = functionMap?['arguments'];
    final argumentsMap = arguments is String
        ? MnnApiTestClient.asJsonMap(arguments)
        : null;
    final checks = <MnnApiValidationCheck>[
      MnnApiValidationCheck(
        id: 'response_object',
        label: '响应根对象有效',
        succeeded: root != null,
      ),
      MnnApiValidationCheck(
        id: 'choices',
        label: 'choices 非空',
        succeeded: choices is List && choices.isNotEmpty,
      ),
      MnnApiValidationCheck(
        id: 'message',
        label: 'assistant message 有效',
        succeeded: messageMap != null,
      ),
      MnnApiValidationCheck(
        id: 'finish_reason',
        label: 'finish_reason=tool_calls',
        succeeded: choiceMap?['finish_reason'] == 'tool_calls',
        detail: '实际值：${choiceMap?['finish_reason'] ?? '-'}',
      ),
      MnnApiValidationCheck(
        id: 'tool_call_count',
        label: 'tool_calls 恰好一个',
        succeeded: calls is List && calls.length == 1,
        detail: '实际数量：${calls is List ? calls.length : 0}',
      ),
      MnnApiValidationCheck(
        id: 'call_id',
        label: 'call id 非空',
        succeeded: id is String && id.trim().isNotEmpty,
      ),
      MnnApiValidationCheck(
        id: 'call_type',
        label: 'tool call type=function',
        succeeded: type == 'function',
      ),
      MnnApiValidationCheck(
        id: 'function_name',
        label: '函数名在白名单中',
        succeeded: name == MnnApiTestClient.toolName,
        detail: '实际值：${name ?? '-'}',
      ),
      MnnApiValidationCheck(
        id: 'arguments_string',
        label: 'arguments 为字符串',
        succeeded: arguments is String,
      ),
      MnnApiValidationCheck(
        id: 'arguments_object',
        label: 'arguments 是 JSON object',
        succeeded: argumentsMap != null,
      ),
      MnnApiValidationCheck(
        id: 'required_city',
        label: 'arguments 包含非空 city',
        succeeded:
            argumentsMap?['city'] is String &&
            (argumentsMap!['city'] as String).trim().isNotEmpty,
      ),
      MnnApiValidationCheck(
        id: 'no_extra_arguments',
        label: 'arguments 无未声明字段',
        succeeded:
            argumentsMap != null &&
            argumentsMap.keys.every((key) => key == 'city'),
      ),
    ];
    final succeeded = checks.every((check) => check.succeeded);
    final parsedArguments = argumentsMap;
    return _ToolValidation(
      checks: checks,
      succeeded: succeeded,
      error: succeeded ? null : '工具调用格式校验失败',
      arguments: parsedArguments,
      argumentsText: arguments is String ? arguments : null,
      call: succeeded && id is String && name is String && messageMap != null
          ? _ToolCall(
              id: id,
              name: name,
              arguments: arguments is String ? arguments : '{}',
              assistantMessage: messageMap,
            )
          : null,
    );
  }

  List<MnnApiValidationCheck> _validateFollowupRequest(
    Map<String, Object?> body, {
    required String expectedToolCallId,
  }) {
    final messages = body['messages'];
    final assistant = messages is List && messages.length > 1
        ? messages[1]
        : null;
    final tool = messages is List && messages.length > 2 ? messages[2] : null;
    final assistantMap = assistant is Map ? assistant : null;
    final toolMap = tool is Map ? tool : null;
    final assistantCalls = assistantMap?['tool_calls'];
    final assistantCall = assistantCalls is List && assistantCalls.isNotEmpty
        ? assistantCalls.first
        : null;
    final assistantCallMap = assistantCall is Map ? assistantCall : null;
    final assistantFunction = assistantCallMap?['function'];
    final assistantFunctionMap = assistantFunction is Map
        ? assistantFunction
        : null;
    final userMap = messages is List && messages.isNotEmpty
        ? messages.first
        : null;
    return <MnnApiValidationCheck>[
      MnnApiValidationCheck(
        id: 'message_order',
        label: 'user → assistant → tool 顺序正确',
        succeeded:
            messages is List &&
            messages.length == 3 &&
            userMap is Map &&
            userMap['role'] == 'user' &&
            assistantMap?['role'] == 'assistant' &&
            toolMap?['role'] == 'tool',
      ),
      MnnApiValidationCheck(
        id: 'assistant_tool_call',
        label: 'assistant 保留唯一完整 tool_call',
        succeeded: assistantCalls is List && assistantCalls.length == 1,
      ),
      MnnApiValidationCheck(
        id: 'assistant_function',
        label: 'assistant function 名称与参数保留',
        succeeded:
            assistantCallMap?['type'] == 'function' &&
            assistantFunctionMap?['name'] == MnnApiTestClient.toolName &&
            assistantFunctionMap?['arguments'] is String,
      ),
      MnnApiValidationCheck(
        id: 'tool_call_id',
        label: 'tool_call_id 与原调用一致',
        succeeded:
            assistantCallMap?['id'] == expectedToolCallId &&
            toolMap?['tool_call_id'] == expectedToolCallId,
      ),
      MnnApiValidationCheck(
        id: 'tool_content',
        label: 'tool content 为 JSON 字符串',
        succeeded:
            toolMap?['content'] is String &&
            MnnApiTestClient.asJsonMap(toolMap?['content']) != null,
      ),
      MnnApiValidationCheck(
        id: 'tool_choice_none',
        label: '续答请求禁止再次选工具',
        succeeded: body['tool_choice'] == 'none',
      ),
      MnnApiValidationCheck(
        id: 'tools_preserved',
        label: '续答请求保留 tools 定义',
        succeeded: body['tools'] is List && (body['tools'] as List).length == 1,
      ),
      MnnApiValidationCheck(
        id: 'stream_false',
        label: '续答请求使用完整 JSON（stream=false）',
        succeeded: body['stream'] == false,
      ),
    ];
  }

  _FinalValidation _validateFinalAnswer(Object? response) {
    final root = MnnApiTestClient.asJsonMap(response);
    final choices = root?['choices'];
    final choice = choices is List && choices.isNotEmpty ? choices.first : null;
    final choiceMap = choice is Map ? choice : null;
    final message = choiceMap?['message'];
    final messageMap = message is Map ? message : null;
    final content = messageMap?['content'];
    final hasAdditionalToolCalls = messageMap?['tool_calls'] != null;
    final checks = <MnnApiValidationCheck>[
      MnnApiValidationCheck(
        id: 'response_object',
        label: '响应根对象有效',
        succeeded: root != null,
      ),
      MnnApiValidationCheck(
        id: 'choices',
        label: 'choices 非空',
        succeeded: choices is List && choices.isNotEmpty,
      ),
      MnnApiValidationCheck(
        id: 'message',
        label: 'assistant message 有效',
        succeeded: messageMap != null && messageMap['role'] == 'assistant',
      ),
      MnnApiValidationCheck(
        id: 'content',
        label: '最终 content 非空',
        succeeded: content is String && content.trim().isNotEmpty,
      ),
      MnnApiValidationCheck(
        id: 'no_tool_calls',
        label: '最终回答未再次请求工具',
        succeeded: messageMap?['tool_calls'] == null,
      ),
      MnnApiValidationCheck(
        id: 'finish_reason',
        label: '结束原因为 stop 或 length',
        succeeded:
            choiceMap?['finish_reason'] == 'stop' ||
            choiceMap?['finish_reason'] == 'length',
        detail: '实际值：${choiceMap?['finish_reason'] ?? '-'}',
      ),
    ];
    final succeeded = checks.every((check) => check.succeeded);
    return _FinalValidation(
      checks: checks,
      succeeded: succeeded,
      error: succeeded
          ? null
          : hasAdditionalToolCalls
          ? 'unexpected_additional_tool_call'
          : '最终回答格式校验失败',
    );
  }

  Map<String, Object?> _executeTool(Map<String, dynamic> arguments) {
    final city = (arguments['city'] as String).trim();
    if (city != '上海' && city.toLowerCase() != 'shanghai') {
      throw StateError('内置测试工具只支持城市：上海。实际值：$city');
    }
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    String two(int value) => value.toString().padLeft(2, '0');
    final timestamp =
        '${now.year}-${two(now.month)}-${two(now.day)}T${two(now.hour)}:'
        '${two(now.minute)}:${two(now.second)}+08:00';
    return <String, Object?>{
      'city': '上海',
      'time': timestamp,
      'timezone': 'Asia/Shanghai',
      'source': 'servllama_mnn_test_tool',
    };
  }

  String _checksText(List<MnnApiValidationCheck> checks) {
    return checks
        .map(
          (check) =>
              '${check.succeeded ? '✓' : '✗'} ${check.label}'
              '${check.detail == null ? '' : '（${check.detail}）'}',
        )
        .join('\n');
  }

  String _flowOutput(List<MnnApiTestStep> steps) {
    return steps
        .map(
          (step) =>
              '${step.status == MnnApiTestStepStatus.succeeded ? '✓' : '✗'} '
              '${step.title}: ${step.status.label}'
              '${step.error == null ? '' : ' - ${step.error}'}',
        )
        .join('\n');
  }

  MnnApiTestResult _result({
    required List<MnnApiTestStep> steps,
    required List<MnnApiExchange> exchanges,
    required int elapsedMs,
    required String output,
    String? toolCallId,
    String? toolName,
    String? toolArguments,
    bool? succeeded,
  }) {
    final completed =
        succeeded ??
        steps.every((step) => step.status == MnnApiTestStepStatus.succeeded);
    final lastExchange = exchanges.isEmpty ? null : exchanges.last;
    return MnnApiTestResult(
      label: '工具调用全流程',
      output: output,
      succeeded: completed,
      elapsedMs: elapsedMs,
      statusCode: lastExchange?.statusCode,
      toolCallId: toolCallId,
      toolName: toolName,
      toolArguments: toolArguments,
      exchanges: List<MnnApiExchange>.unmodifiable(exchanges),
      steps: List<MnnApiTestStep>.unmodifiable(steps),
      errorMessage: steps
          .where((step) => step.status == MnnApiTestStepStatus.failed)
          .map((step) => step.error)
          .whereType<String>()
          .firstOrNull,
    );
  }

  Map<String, String> _headers(String? apiKey) => <String, String>{
    'Content-Type': 'application/json',
    if (apiKey != null && apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
  };
}

class _ToolValidation {
  const _ToolValidation({
    required this.checks,
    required this.succeeded,
    required this.error,
    required this.arguments,
    required this.argumentsText,
    required this.call,
  });

  final List<MnnApiValidationCheck> checks;
  final bool succeeded;
  final String? error;
  final Map<String, dynamic>? arguments;
  final String? argumentsText;
  final _ToolCall? call;
}

class _ToolCall {
  const _ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    required this.assistantMessage,
  });

  final String id;
  final String name;
  final String arguments;
  final Map<String, dynamic> assistantMessage;
}

class _FinalValidation {
  const _FinalValidation({
    required this.checks,
    required this.succeeded,
    required this.error,
  });

  final List<MnnApiValidationCheck> checks;
  final bool succeeded;
  final String? error;
}
