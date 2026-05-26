import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast.dart';
import '../storage/deck_repository.dart';
import 'controllers/deck_list_controller.dart';
import 'deck_list_screen.dart';

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
      ],
      child: MaterialApp(
        title: 'ankiyo',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const DeckListScreen(),
      ),
    );
  }
}
