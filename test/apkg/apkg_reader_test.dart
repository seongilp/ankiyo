import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/apkg/apkg_reader.dart';

void main() {
  test('구형 .apkg에서 collection.anki21 바이트를 추출한다', () {
    final bytes = File('test/fixtures/sample.apkg').readAsBytesSync();
    final db = ApkgReader.extractCollection(bytes);
    // SQLite 파일 매직 헤더
    expect(String.fromCharCodes(db.sublist(0, 15)), 'SQLite format 3');
  });

  test('컬렉션이 없는 zip은 UnsupportedApkgException', () {
    expect(
      () => ApkgReader.extractCollection(_emptyZip()),
      throwsA(isA<UnsupportedApkgException>()),
    );
  });
}

// 빈 zip 바이트 (PK 헤더만 있는 최소 zip)
List<int> _emptyZip() => [0x50, 0x4b, 0x05, 0x06, ...List.filled(18, 0)];
