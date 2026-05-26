import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/storage/settings_store.dart';

void main() {
  test('기본값을 반환하고 저장/로드된다', () async {
    final db = await databaseFactoryMemory.openDatabase('s.db');
    final store = SettingsStore(db);

    final defaults = await store.load();
    expect(defaults.newLimit, 20);
    expect(defaults.reviewLimit, 200);

    await store.save(const SrsSettings(newLimit: 5, reviewLimit: 50));
    final loaded = await store.load();
    expect(loaded.newLimit, 5);
    expect(loaded.reviewLimit, 50);
  });
}
