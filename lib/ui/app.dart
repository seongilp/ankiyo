import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast.dart';
import '../storage/deck_repository.dart';
import '../storage/settings_store.dart';
import 'controllers/deck_list_controller.dart';
import 'controllers/settings_controller.dart';
import 'deck_list_screen.dart';
import 'theme.dart';

class AnkiyoApp extends StatelessWidget {
  final Database db;
  const AnkiyoApp({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    final repo = DeckRepository(db);
    return MultiProvider(
      providers: [
        Provider<DeckRepository>.value(value: repo),
        ChangeNotifierProvider(create: (_) => DeckListController(repo)),
        ChangeNotifierProvider(
            create: (_) => SettingsController(SettingsStore(db))..load()),
      ],
      child: MaterialApp(
        title: 'ankiyo',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const DeckListScreen(),
      ),
    );
  }
}
