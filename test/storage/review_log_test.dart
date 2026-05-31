import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/storage/review_log.dart';

void main() {
  var seq = 0;
  Future<ReviewLogStore> setup() async {
    final db =
        await databaseFactoryMemory.openDatabase('log_${seq++}.db');
    return ReviewLogStore(db);
  }

  test('countToday: 오늘 자정 기준 누적, 덱별 필터', () async {
    final store = await setup();
    final now = DateTime(2026, 5, 29, 22, 0);
    await store.append(ReviewLogEntry(
        cardId: 'c1',
        deckId: 'A',
        rating: Rating.good,
        at: DateTime(2026, 5, 29, 8, 0)));
    await store.append(ReviewLogEntry(
        cardId: 'c2',
        deckId: 'A',
        rating: Rating.again,
        at: DateTime(2026, 5, 29, 20, 0)));
    await store.append(ReviewLogEntry(
        cardId: 'c3',
        deckId: 'B',
        rating: Rating.good,
        at: DateTime(2026, 5, 29, 12, 0)));
    // 어제 entry — 카운트 제외
    await store.append(ReviewLogEntry(
        cardId: 'c4',
        deckId: 'A',
        rating: Rating.good,
        at: DateTime(2026, 5, 28, 23, 59)));

    expect(await store.countToday(now: now), 3);
    expect(await store.countToday(deckId: 'A', now: now), 2);
    expect(await store.countToday(deckId: 'B', now: now), 1);
    expect(await store.countToday(deckId: 'C', now: now), 0);
  });

  test('weakCardIds: 카드별 최신 평가가 Again/Hard일 때만 포함', () async {
    final store = await setup();
    final now = DateTime(2026, 5, 29, 12);

    // c1: Again → Good (회복) → 제외
    await store.append(ReviewLogEntry(
        cardId: 'c1',
        deckId: 'A',
        rating: Rating.again,
        at: now.subtract(const Duration(days: 1))));
    await store.append(ReviewLogEntry(
        cardId: 'c1',
        deckId: 'A',
        rating: Rating.good,
        at: now.subtract(const Duration(hours: 2))));

    // c2: Good → Hard (악화) → 포함
    await store.append(ReviewLogEntry(
        cardId: 'c2',
        deckId: 'A',
        rating: Rating.good,
        at: now.subtract(const Duration(days: 2))));
    await store.append(ReviewLogEntry(
        cardId: 'c2',
        deckId: 'A',
        rating: Rating.hard,
        at: now.subtract(const Duration(hours: 1))));

    // c3: 단독 Again → 포함
    await store.append(ReviewLogEntry(
        cardId: 'c3',
        deckId: 'A',
        rating: Rating.again,
        at: now.subtract(const Duration(hours: 3))));

    // c4: Easy → 제외
    await store.append(ReviewLogEntry(
        cardId: 'c4',
        deckId: 'A',
        rating: Rating.easy,
        at: now.subtract(const Duration(hours: 5))));

    final weak = await store.weakCardIds(now: now);
    expect(weak, {'c2', 'c3'});
  });

  test('weakCardIds: 7일 창 바깥은 무시', () async {
    final store = await setup();
    final now = DateTime(2026, 5, 29, 12);

    await store.append(ReviewLogEntry(
        cardId: 'old',
        deckId: 'A',
        rating: Rating.again,
        at: now.subtract(const Duration(days: 8))));
    await store.append(ReviewLogEntry(
        cardId: 'recent',
        deckId: 'A',
        rating: Rating.hard,
        at: now.subtract(const Duration(days: 2))));

    final weak = await store.weakCardIds(now: now);
    expect(weak, {'recent'});
  });
}
