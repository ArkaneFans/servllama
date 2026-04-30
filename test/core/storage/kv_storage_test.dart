import 'package:flutter_test/flutter_test.dart';
import 'package:servllama/core/storage/kv_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('KvStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('reads and writes supported value types', () async {
      final store = KvStorage();

      await store.setString('string', 'value');
      await store.setInt('int', 42);
      await store.setBool('bool', true);
      await store.setDouble('double', 1.5);
      await store.setStringList('list', <String>['a', 'b']);

      expect(await store.getString('string'), 'value');
      expect(await store.getInt('int'), 42);
      expect(await store.getBool('bool'), isTrue);
      expect(await store.getDouble('double'), 1.5);
      expect(await store.getStringList('list'), <String>['a', 'b']);
      expect(await store.getString('missing'), isNull);
    });

    test('containsKey remove and clear behave correctly', () async {
      final store = KvStorage();

      await store.setString('key', 'value');
      expect(await store.containsKey('key'), isTrue);

      await store.remove('key');
      expect(await store.containsKey('key'), isFalse);

      await store.setInt('another', 1);
      await store.clear();
      expect(await store.containsKey('another'), isFalse);
    });
  });
}
