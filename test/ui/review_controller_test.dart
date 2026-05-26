import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/srs/scheduler.dart';
import 'package:ankiyo/storage/deck_repository.dart';
import 'package:ankiyo/storage/models.dart';
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
}
