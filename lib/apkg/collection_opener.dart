import 'dart:typed_data';
import 'package:sqlite3/common.dart';
import 'collection_opener_web.dart'
    if (dart.library.io) 'collection_opener_native.dart' as impl;

/// 추출된 SQLite 바이트로부터 [CommonDatabase]를 연다.
/// 웹/네이티브 구현이 다르다.
abstract class CollectionOpener {
  Future<CommonDatabase> open(Uint8List dbBytes);
}

/// 현재 플랫폼에 맞는 구현을 반환.
CollectionOpener createCollectionOpener() => impl.createCollectionOpener();
