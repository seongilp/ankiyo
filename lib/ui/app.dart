import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast.dart';
import '../llm/anthropic_client.dart';
import '../llm/word_extractor.dart';
import '../storage/deck_repository.dart';
import '../storage/review_log.dart';
import '../storage/settings_store.dart';
import 'controllers/deck_list_controller.dart';
import 'controllers/settings_controller.dart';
import 'deck_list_screen.dart';
import 'theme.dart';

class AnkiyoApp extends StatelessWidget {
  final Database db;
  final String anthropicApiKey;
  final String anthropicBaseUrl;
  final String gatewayToken;
  const AnkiyoApp({
    super.key,
    required this.db,
    required this.anthropicApiKey,
    required this.anthropicBaseUrl,
    this.gatewayToken = '',
  });

  @override
  Widget build(BuildContext context) {
    final repo = DeckRepository(db);
    final extractor = WordExtractor(AnthropicClient(
      apiKey: anthropicApiKey,
      baseUrl: anthropicBaseUrl,
      gatewayToken: gatewayToken,
    ));
    final reviewLog = ReviewLogStore(db);
    final settingsStore = SettingsStore(db);
    return MultiProvider(
      providers: [
        Provider<DeckRepository>.value(value: repo),
        Provider<WordExtractor>.value(value: extractor),
        Provider<ReviewLogStore>.value(value: reviewLog),
        ChangeNotifierProvider(
            create: (_) => DeckListController(repo, settingsStore, reviewLog)),
        ChangeNotifierProvider(
            create: (_) => SettingsController(settingsStore)..load()),
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
