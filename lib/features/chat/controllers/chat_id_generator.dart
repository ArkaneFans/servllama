import 'dart:math';

class ChatIdGenerator {
  ChatIdGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  String generate(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
  }
}
