import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/common.dart';
import 'package:sqlite3/sqlite3.dart';
import 'collection_opener.dart';

/// 네이티브: 임시 디렉토리에 sqlite 바이트를 쓰고 sqlite3로 연다.
/// sqlite3_flutter_libs가 .so/.dylib을 번들해서 sqlite3 패키지가 그대로 동작.
class NativeCollectionOpener implements CollectionOpener {
  @override
  Future<CommonDatabase> open(Uint8List dbBytes) async {
    final tmp = await getTemporaryDirectory();
    final file = File(p.join(tmp.path,
        'collection_${DateTime.now().millisecondsSinceEpoch}.db'));
    await file.writeAsBytes(dbBytes, flush: true);
    return sqlite3.open(file.path);
  }
}

CollectionOpener createCollectionOpener() => NativeCollectionOpener();
