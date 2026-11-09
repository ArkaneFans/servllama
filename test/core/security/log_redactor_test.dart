import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/security/log_redactor.dart';

void main() {
  test('diagnostics keep ordinary text while masking credentials', () {
    LogRedactor.remember('known-secret');
    final text = LogRedactor.redact(
      'Startup failed: --api-key known-secret Authorization: Bearer header-secret '
      'unlabelled known-secret',
    );
    expect(text, contains('Startup failed'));
    expect(text, contains('[REDACTED]'));
    expect(text, isNot(contains('known-secret')));
    expect(text, isNot(contains('header-secret')));
  });
}
