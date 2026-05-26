import 'dart:typed_data';
import 'package:archive/archive.dart';

class UnsupportedApkgException implements Exception {
  final String message;
  const UnsupportedApkgException(this.message);
  @override
  String toString() => 'UnsupportedApkgException: $message';
}

class ApkgReader {
  /// .apkg(zip) 바이트에서 SQLite 컬렉션 바이트를 추출한다.
  /// 구형 포맷(collection.anki21 / collection.anki2)만 지원.
  static Uint8List extractCollection(List<int> apkgBytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(apkgBytes);
    } catch (e) {
      throw const UnsupportedApkgException('zip을 읽을 수 없습니다. .apkg 파일이 맞나요?');
    }

    // 신형(zstd) 포맷 감지: collection.anki21b가 있으면 미지원
    if (archive.findFile('collection.anki21b') != null) {
      throw const UnsupportedApkgException(
          '신형(압축) .apkg는 아직 지원되지 않습니다. Anki에서 "이전 버전 지원"을 켜고 다시 내보내 주세요.');
    }

    final file = archive.findFile('collection.anki21') ??
        archive.findFile('collection.anki2');
    if (file == null) {
      throw const UnsupportedApkgException(
          '컬렉션 데이터를 찾지 못했습니다. 올바른 Anki 덱 파일이 아닙니다.');
    }
    return Uint8List.fromList(file.content as List<int>);
  }
}
