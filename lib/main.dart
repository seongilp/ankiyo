import 'package:flutter/material.dart';
import 'storage/db.dart';
import 'ui/app.dart';

const _apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
const _baseUrl = String.fromEnvironment('ANTHROPIC_BASE_URL',
    defaultValue: 'https://api.anthropic.com');
const _gatewayToken = String.fromEnvironment('CF_AIG_TOKEN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();
  runApp(AnkiyoApp(
    db: db,
    anthropicApiKey: _apiKey,
    anthropicBaseUrl: _baseUrl,
    gatewayToken: _gatewayToken,
  ));
}
