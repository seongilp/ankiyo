import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

/// 웹: IndexedDB. (네이티브 포팅 시 sembast_io로 분기 추가)
Future<Database> openAppDatabase() async {
  final factory = databaseFactoryWeb;
  return factory.openDatabase('ankiyo.db');
}
