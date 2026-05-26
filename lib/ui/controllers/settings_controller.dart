import 'package:flutter/foundation.dart';
import '../../storage/settings_store.dart';

class SettingsController extends ChangeNotifier {
  final SettingsStore store;
  SettingsController(this.store);

  SrsSettings settings = const SrsSettings();

  Future<void> load() async {
    settings = await store.load();
    notifyListeners();
  }

  Future<void> update(SrsSettings s) async {
    settings = s;
    await store.save(s);
    notifyListeners();
  }
}
