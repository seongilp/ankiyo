import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/apkg/anki_db.dart';
import 'package:ankiyo/storage/deck_repository.dart';
import 'package:ankiyo/storage/import_service.dart';

void main() {
  test('ParsedDeck/ParsedCard를 덱별로 저장한다', () async {
    final db = await databaseFactoryMemory.openDatabase('imp.db');
    final repo = DeckRepository(db);
    final service = ImportService(repo);

    final decks = [
      const ParsedDeck(ankiId: 2, name: 'Korean::Capitals'),
      const ParsedDeck(ankiId: 1, name: 'Default'),
    ];
    final cards = [
      const ParsedCard(
          deckAnkiId: 2, frontHtml: 'Bonjour', backHtml: 'Hello', isCloze: false),
      const ParsedCard(
          deckAnkiId: 2, frontHtml: 'Merci', backHtml: 'Thanks', isCloze: false),
    ];

    final saved = await service.importParsed(
        decks: decks, cards: cards, now: DateTime.utc(2026, 1, 1));

    // 카드가 0장인 덱(Default)은 저장하지 않는다
    expect(saved.length, 1);
    expect(saved.first.name, 'Korean::Capitals');

    final loaded = await repo.getCards(saved.first.id);
    expect(loaded.length, 2);
    // 신규 카드 상태로 시작
    expect(loaded.every((c) => c.state.reps == 0), true);
  });
}
