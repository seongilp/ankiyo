import 'package:flutter/material.dart';
import 'storage/db.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await openAppDatabase();
  runApp(AnkiyoApp(db: db));
}
