import 'dart:typed_data';
import 'package:sqlite3/wasm.dart';
import 'package:typed_data/typed_buffers.dart';
import 'collection_opener.dart';

/// 웹 전용: sqlite3.wasm을 로드하고 인메모리 VFS에 바이트를 써서 연다.
/// (sqlite3 3.3.1 API: registerVirtualFileSystem + InMemoryFileSystem.fileData)
class WebCollectionOpener implements CollectionOpener {
  WasmSqlite3? _sqlite3;
  bool _vfsRegistered = false;
  final InMemoryFileSystem _fs = InMemoryFileSystem();

  static const _path = '/collection.db';

  @override
  Future<CommonDatabase> open(Uint8List dbBytes) async {
    _sqlite3 ??= await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
    if (!_vfsRegistered) {
      _sqlite3!.registerVirtualFileSystem(_fs, makeDefault: true);
      _vfsRegistered = true;
    }
    // 인메모리 FS에 DB 바이트를 주입한 뒤 연다.
    _fs.fileData[_path] = Uint8Buffer()..addAll(dbBytes);
    return _sqlite3!.open(_path);
  }
}
