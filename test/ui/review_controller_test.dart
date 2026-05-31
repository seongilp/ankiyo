import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/srs/scheduler.dart';
import 'package:ankiyo/storage/deck_repository.dart';
import 'package:ankiyo/storage/models.dart';
import 'package:ankiyo/storage/review_log.dart';
import 'package:ankiyo/ui/controllers/review_controller.dart';

void main() {
  test('평가하면 다음 카드로 진행하고 상태를 저장한다', () async {
    final now = DateTime.utc(2026, 1, 1, 9);
    final db = await databaseFactoryMemory.openDatabase('rc.db');
    final repo = DeckRepository(db);
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
    await repo.saveDeck(Deck(id: 'd1', name: 'D', importedAt: now), cards);

    final controller = ReviewController(
      repo: repo,
      scheduler: const Scheduler(),
      deckId: 'd1',
      newLimit: 20,
      reviewLimit: 200,
      clock: () => now,
    );
    await controller.load();
    expect(controller.remaining, 2);
    expect(controller.showingBack, false);

    controller.reveal();
    expect(controller.showingBack, true);

    await controller.rate(Rating.good);
    expect(controller.remaining, 1); // 다음 카드로

    // 저장 반영 확인
    final saved = await repo.getCards('d1');
    expect(
        saved.any((c) =>
            c.state.reps > 0 || c.state.status != CardStatus.newCard),
        true);
  });

  group('drill mode', () {
    test('drillMode 평가는 카드 상태를 바꾸지 않지만 로그는 남긴다', () async {
      final now = DateTime.utc(2026, 5, 29, 22);
      final db = await databaseFactoryMemory.openDatabase('drill.db');
      final repo = DeckRepository(db);
      final log = ReviewLogStore(db);
      final card = StudyCard(
        id: 'cx',
        deckId: 'd1',
        frontHtml: 'F',
        backHtml: 'B',
        isCloze: false,
        state: CardState.create(now)
            .copyWith(status: CardStatus.review, intervalDays: 10, reps: 3),
      );
      await repo.saveDeck(Deck(id: 'd1', name: 'D', importedAt: now), [card]);

      final controller = ReviewController(
        repo: repo,
        scheduler: const Scheduler(),
        log: log,
        drillMode: true,
        drillCardIds: {'cx'},
        newLimit: 0,
        reviewLimit: 0,
        clock: () => now,
      );
      await controller.load();
      expect(controller.total, 1);

      controller.reveal();
      await controller.rate(Rating.good);

      // 카드 상태는 그대로 (review, 10일, 3 reps)
      final saved = await repo.getCards('d1');
      expect(saved.first.state.status, CardStatus.review);
      expect(saved.first.state.intervalDays, 10);
      expect(saved.first.state.reps, 3);

      // 로그엔 남는다
      final entries = await log.all();
      expect(entries.length, 1);
      expect(entries.first.cardId, 'cx');
      expect(entries.first.rating, Rating.good);
    });

    test('previewLabel은 시간 단위까지 사람이 읽는 형태로 보여준다', () async {
      final now = DateTime.utc(2026, 5, 30, 9);
      final db = await databaseFactoryMemory.openDatabase('label.db');
      final repo = DeckRepository(db);
      await repo.saveDeck(
        Deck(id: 'd1', name: 'D', importedAt: now),
        [
          StudyCard(
              id: 'c1',
              deckId: 'd1',
              frontHtml: 'F',
              backHtml: 'B',
              isCloze: false,
              state: CardState.create(now)),
        ],
      );
      final controller = ReviewController(
        repo: repo,
        scheduler: const Scheduler(),
        deckId: 'd1',
        newLimit: 20,
        reviewLimit: 200,
        clock: () => now,
      );
      await controller.load();

      // 새 카드: Again → 10분, Good → 10시간, Easy → 4일
      expect(controller.previewLabel(Rating.again), '10분');
      expect(controller.previewLabel(Rating.good), '10시간');
      expect(controller.previewLabel(Rating.easy), '4일');
    });

    test('drillMode에선 previewLabel 비어있음', () async {
      final now = DateTime.utc(2026, 5, 29);
      final db = await databaseFactoryMemory.openDatabase('drill2.db');
      final repo = DeckRepository(db);
      final card = StudyCard(
        id: 'cx',
        deckId: 'd1',
        frontHtml: 'F',
        backHtml: 'B',
        isCloze: false,
        state: CardState.create(now),
      );
      await repo.saveDeck(Deck(id: 'd1', name: 'D', importedAt: now), [card]);

      final controller = ReviewController(
        repo: repo,
        scheduler: const Scheduler(),
        drillMode: true,
        drillCardIds: {'cx'},
        newLimit: 0,
        reviewLimit: 0,
        clock: () => now,
      );
      await controller.load();

      for (final r in Rating.values) {
        expect(controller.previewLabel(r), '');
      }
    });

    test('drillMode에선 nextDueAtForDeck이 null', () async {
      final now = DateTime.utc(2026, 5, 29);
      final db = await databaseFactoryMemory.openDatabase('drill3.db');
      final repo = DeckRepository(db);
      await repo.saveDeck(
          Deck(id: 'd1', name: 'D', importedAt: now), [
        StudyCard(
            id: 'cx',
            deckId: 'd1',
            frontHtml: 'F',
            backHtml: 'B',
            isCloze: false,
            state: CardState.create(now)),
      ]);

      final controller = ReviewController(
        repo: repo,
        scheduler: const Scheduler(),
        drillMode: true,
        drillCardIds: {'cx'},
        newLimit: 0,
        reviewLimit: 0,
        clock: () => now,
      );
      expect(await controller.nextDueAtForDeck(), isNull);
    });
  });
}
