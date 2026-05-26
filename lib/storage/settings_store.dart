import 'package:sembast/sembast.dart';

class SrsSettings {
  final int newLimit;
  final int reviewLimit;
  const SrsSettings({this.newLimit = 20, this.reviewLimit = 200});

  Map<String, Object?> toMap() =>
      {'newLimit': newLimit, 'reviewLimit': reviewLimit};

  factory SrsSettings.fromMap(Map<String, Object?> m) => SrsSettings(
        newLimit: (m['newLimit'] as num?)?.toInt() ?? 20,
        reviewLimit: (m['reviewLimit'] as num?)?.toInt() ?? 200,
      );
}

class SettingsStore {
  final Database _db;
  final _store = stringMapStoreFactory.store('settings');
  static const _key = 'srs';

  SettingsStore(this._db);

  Future<SrsSettings> load() async {
    final m = await _store.record(_key).get(_db);
    return m == null ? const SrsSettings() : SrsSettings.fromMap(m);
  }

  Future<void> save(SrsSettings s) async {
    await _store.record(_key).put(_db, s.toMap());
  }
}
