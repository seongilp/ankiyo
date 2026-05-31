import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/storage/deck_repository.dart';
import 'package:ankiyo/storage/models.dart';
import 'package:ankiyo/storage/review_log.dart';
import 'package:ankiyo/storage/settings_store.dart';
import 'package:ankiyo/ui/controllers/deck_list_controller.dart';

void main() {
  final fixedNow = DateTime(2026, 5, 29, 22);

  StudyCard newCard(String id, String deckId, DateTime now) => StudyCard(
        id: id,
        deckId: deckId,
        frontHtml: 'F',
        backHtml: 'B',
        isCloze: false,
        state: CardState.create(now),
      );

  var seq = 0;
  Future<(DeckListController, DeckRepository, ReviewLogStore)> build({
    int newLimit = 20,
    int reviewLimit = 200,
  }) async {
    final db = await databaseFactoryMemory.openDatabase('dl_${seq++}.db');
    final repo = DeckRepository(db);
    final settings = SettingsStore(db);
    await settings.save(
        SrsSettings(newLimit: newLimit, reviewLimit: reviewLimit));
    final log = ReviewLogStore(db);
    final c = DeckListController(repo, settings, log, clock: () => fixedNow);
    return (c, repo, log);
  }

  test('due 카운트가 일일 한도(newLimit)에 캡된다', () async {
    final (c, repo, _) = await build(newLimit: 20);
    final deck = Deck(id: 'd1', name: 'EBS', importedAt: fixedNow);
    final cards =
        List.generate(141, (i) => newCard('c$i', 'd1', fixedNow));
    await repo.saveDeck(deck, cards);

    await c.load();

    expect(c.summaries.length, 1);
    expect(c.summaries.first.total, 141);
    expect(c.summaries.first.due, 20); // 141장 신규지만 한도 20에 캡
  });

  test('studiedToday는 오늘 review_log 누적 — 세션을 거듭해도 늘어난다', () async {
    final (c, repo, log) = await build();
    await repo.saveDeck(
        Deck(id: 'd1', name: 'X', importedAt: fixedNow),
        List.generate(10, (i) => newCard('c$i', 'd1', fixedNow)));

    for (var i = 0; i < 7; i++) {
      await log.append(ReviewLogEntry(
          cardId: 'c$i',
          deckId: 'd1',
          rating: Rating.good,
          at: fixedNow.subtract(const Duration(hours: 1))));
    }

    await c.load();
    expect(c.summaries.first.studiedToday, 7);
  });

  test('어제 로그는 studiedToday에 포함되지 않는다', () async {
    final (c, repo, log) = await build();
    await repo.saveDeck(
        Deck(id: 'd1', name: 'X', importedAt: fixedNow),
        [newCard('c0', 'd1', fixedNow)]);
    await log.append(ReviewLogEntry(
        cardId: 'c0',
        deckId: 'd1',
        rating: Rating.good,
        at: fixedNow.subtract(const Duration(days: 1))));

    await c.load();
    expect(c.summaries.first.studiedToday, 0);
  });

  test('weakCount: 최근 7일 안 카드별 최신 평가가 Again/Hard인 유니크 수', () async {
    final (c, repo, log) = await build();
    await repo.saveDeck(
        Deck(id: 'd1', name: 'X', importedAt: fixedNow),
        [newCard('c0', 'd1', fixedNow)]);

    await log.append(ReviewLogEntry(
        cardId: 'a',
        deckId: 'd1',
        rating: Rating.again,
        at: fixedNow.subtract(const Duration(hours: 2))));
    await log.append(ReviewLogEntry(
        cardId: 'b',
        deckId: 'd1',
        rating: Rating.hard,
        at: fixedNow.subtract(const Duration(hours: 1))));
    await log.append(ReviewLogEntry(
        cardId: 'c',
        deckId: 'd1',
        rating: Rating.good,
        at: fixedNow.subtract(const Duration(hours: 1))));

    await c.load();
    expect(c.weakCount, 2);
  });
}
