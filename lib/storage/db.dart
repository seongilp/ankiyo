import 'package:sembast/sembast.dart';
import 'db_web.dart' if (dart.library.io) 'db_native.dart' as impl;

/// 웹: IndexedDB (sembast_web). 네이티브: 앱 문서 디렉토리의 파일 (sembast_io).
Future<Database> openAppDatabase() => impl.openAppDatabase();
