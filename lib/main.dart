import 'package:flutter/material.dart';
import 'storage/db.dart';
import 'storage/deck_repository.dart';
import 'storage/seed_service.dart';
import 'ui/app.dart';

const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
const _baseUrl = String.fromEnvironment('ANTHROPIC_BASE_URL',
    defaultValue: 'https://api.anthropic.com');
const _gatewayToken = String.fromEnvironment('CF_AIG_TOKEN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();
  // 첫 실행 시 기본 내장 공부셋(일본어 교재 덱)을 한 번만 시드한다.
  try {
    await SeedService(DeckRepository(db), db).seedIfNeeded(DateTime.now());
  } catch (_) {
    // 시딩 실패가 앱 부팅을 막지 않도록 무시한다.
  }
  runApp(AnkiyoApp(
    db: db,
    anthropicApiKey: _apiKey,
    anthropicBaseUrl: _baseUrl,
    gatewayToken: _gatewayToken,
  ));
}
