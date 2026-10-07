/// Validates the JSON Schema subset used by local tools and ordinary MCP tools.
/// Unknown annotation keywords do not grant permissions or execute anything.
void validateToolArguments(
  Object? value,
  Map<String, dynamic> schema, {
  int depth = 0,
}) {
  if (depth > 16) throw const FormatException('Tool schema nesting limit');
  final type = schema['type'];
  final valid = switch (type) {
    'object' => value is Map,
    'array' => value is List,
    'string' => value is String,
    'number' => value is num,
    'integer' => value is int,
    'boolean' => value is bool,
    'null' => value == null,
    null => true,
    _ => false,
  };
  if (!valid) throw const FormatException('Tool argument type mismatch');
  if (schema['enum'] is List && !(schema['enum'] as List).contains(value)) {
    throw const FormatException('Invalid enum value');
  }
  if (value is String &&
      value.length > (schema['maxLength'] as int? ?? 262144)) {
    throw const FormatException('Tool argument too long');
  }
  if (value is num) {
    if (schema['minimum'] is num && value < (schema['minimum'] as num) ||
        schema['maximum'] is num && value > (schema['maximum'] as num)) {
      throw const FormatException('Tool argument out of range');
    }
  }
  if (value is Map) {
    final properties = schema['properties'] as Map? ?? {};
    for (final required in schema['required'] as List? ?? []) {
      if (!value.containsKey(required)) {
        throw FormatException('Required tool argument missing: $required');
      }
    }
    for (final key in value.keys) {
      final child = properties[key];
      if (child is Map) {
        validateToolArguments(
          value[key],
          Map<String, dynamic>.from(child),
          depth: depth + 1,
        );
      } else if (schema['additionalProperties'] == false) {
        throw const FormatException('Unexpected tool argument');
      }
    }
  }
  if (value is List) {
    if (value.length > (schema['maxItems'] as int? ?? 256)) {
      throw const FormatException('Too many tool arguments');
    }
    final item = schema['items'];
    if (item is Map) {
      for (final v in value) {
        validateToolArguments(
          v,
          Map<String, dynamic>.from(item),
          depth: depth + 1,
        );
      }
    }
  }
}
