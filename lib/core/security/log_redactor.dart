/// Shared by in-memory diagnostics, disk logs and developer output.
class LogRedactor {
  LogRedactor._();
  static final Set<String> _secrets = {};
  static final _credential = RegExp(
    r'''((?:--api-key|api[_-]?key|authorization|access[_-]?token|bearer|password)\s*["']?\s*[:=]?\s*["']?\s*)(?:Bearer\s+)?([^\s,"'&}\]]+)''',
    caseSensitive: false,
  );
  static void remember(String value) {
    if (value.length >= 4) _secrets.add(value);
  }

  static String redact(String text) {
    var result = text.replaceAllMapped(
      _credential,
      (match) => '${match[1]!}[REDACTED]',
    );
    for (final secret in _secrets) {
      result = result.replaceAll(secret, '[REDACTED]');
    }
    return result;
  }
}
