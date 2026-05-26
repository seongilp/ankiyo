import 'dart:typed_data';
import 'package:sqlite3/common.dart';

/// 추출된 SQLite 바이트로부터 [CommonDatabase]를 연다.
/// 웹/네이티브 구현이 다르다 (현재는 웹 구현만 제공).
abstract class CollectionOpener {
  Future<CommonDatabase> open(Uint8List dbBytes);
}
