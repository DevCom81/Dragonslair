import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('enemy client repository is read-only', () {
    final src = File(
      'lib/features/enemies/data/supabase_enemy_repository.dart',
    ).readAsStringSync();
    expect(src.contains(".from('enemies')"), isTrue);
    expect(src.contains('.select()'), isTrue);
    expect(src.contains('.insert('), isFalse);
    expect(src.contains('.update('), isFalse);
    expect(src.contains('.upsert('), isFalse);
    expect(src.contains('.delete('), isFalse);
  });
}
