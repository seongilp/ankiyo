import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/storage/models.dart';
import 'package:ankiyo/storage/deck_repository.dart';

void main() {
  late DeckRepository repo;

  setUp(() async {
    final db = await databaseFactoryMemory.openDatabase('test.db');
    repo = DeckRepository(db);
  });

  test('덱과 카드를 저장하고 다시 읽는다', () async {
    final now = DateTime.utc(2026, 1, 1);
    final deck = Deck(id: 'd1', name: 'Korean', importedAt: now);
    final cards = [
      StudyCard(
          id: 'c1',
          deckId: 'd1',
          frontHtml: 'A',
          backHtml: 'B',
          isCloze: false,
          state: CardState.create(now)),
      StudyCard(
          id: 'c2',
          deckId: 'd1',
          frontHtml: 'C',
          backHtml: 'D',
          isCloze: false,
          state: CardState.create(now)),
    ];
    await repo.saveDeck(deck, cards);

    final decks = await repo.getDecks();
    expect(decks.map((d) => d.name), ['Korean']);

    final loaded = await repo.getCards('d1');
    expect(loaded.length, 2);
  });

  test('카드 상태 갱신이 반영된다', () async {
    final now = DateTime.utc(2026, 1, 1);
    final card = StudyCard(
        id: 'c1',
        deckId: 'd1',
        frontHtml: 'A',
        backHtml: 'B',
        isCloze: false,
        state: CardState.create(now));
    await repo.saveDeck(Deck(id: 'd1', name: 'D', importedAt: now), [card]);

    await repo.updateCard(card.withState(card.state.copyWith(reps: 9)));
    final loaded = await repo.getCards('d1');
    expect(loaded.first.state.reps, 9);
  });

  test('덱 삭제 시 카드도 삭제된다', () async {
    final now = DateTime.utc(2026, 1, 1);
    await repo.saveDeck(Deck(id: 'd1', name: 'D', importedAt: now), [
      StudyCard(
          id: 'c1',
          deckId: 'd1',
          frontHtml: 'A',
          backHtml: 'B',
          isCloze: false,
          state: CardState.create(now)),
    ]);
    await repo.deleteDeck('d1');
    expect(await repo.getDecks(), isEmpty);
    expect(await repo.getCards('d1'), isEmpty);
  });
}
