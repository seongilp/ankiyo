import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:ankiyo/apkg/apkg_reader.dart';
import 'package:ankiyo/apkg/anki_db.dart';

void main() {
  test('샘플 컬렉션에서 덱별 카드 앞/뒤를 추출한다', () {
    final apkg = File('test/fixtures/sample.apkg').readAsBytesSync();
    final dbBytes = ApkgReader.extractCollection(apkg);

    // 네이티브: 바이트를 임시 파일로 써서 연다
    final tmp = File('${Directory.systemTemp.path}/anki_test.db');
    tmp.writeAsBytesSync(dbBytes);
    final db = sqlite3.open(tmp.path);

    final reader = AnkiCollectionReader(db);
    final decks = reader.readDecks();
    expect(decks.any((d) => d.name == 'Korean::Capitals' && d.ankiId == 2), true);

    final cards = reader.readCards();
    expect(cards.length, 2);
    final bonjour = cards.firstWhere((c) => c.frontHtml.contains('Bonjour'));
    expect(bonjour.backHtml, contains('Hello'));
    expect(bonjour.deckAnkiId, 2);

    db.dispose();
    tmp.deleteSync();
  });
}
