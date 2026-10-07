import 'package:servllama/shared/widgets/app_message.dart';
import 'package:flutter/material.dart';
import 'package:servllama/core/logging/app_logger.dart';
import 'package:servllama/core/security/log_redactor.dart';
import 'package:servllama/l10n/l10n.dart';

Future<void> runUiAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    AppLogger.instance.event(
      'ui.action.failed',
      level: LogLevel.error,
      fields: AppLogger.errorFields(e),
    );
    if (context.mounted) {
      AppMessage.show(
        context,
        '${context.l10n.v2OperationFailed}\n${LogRedactor.redact(e.toString())}',
        tone: AppMessageTone.error,
      );
    }
  }
}
