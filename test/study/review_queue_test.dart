import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/storage/models.dart';
import 'package:ankiyo/study/review_queue.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 9);

  StudyCard card(String id, CardStatus status, DateTime due) => StudyCard(
        id: id,
        deckId: 'd',
        frontHtml: id,
        backHtml: id,
        isCloze: false,
        state: CardState.create(now).copyWith(status: status, due: due),
      );

  test('만기된 학습/복습 카드만, 한도 내 신규 카드를 포함한다', () {
    final cards = [
      card('new1', CardStatus.newCard, now),
      card('new2', CardStatus.newCard, now),
      card('new3', CardStatus.newCard, now),
      card('due_review', CardStatus.review, now.subtract(const Duration(hours: 1))),
      card('future_review', CardStatus.review, now.add(const Duration(days: 3))),
      card('due_learn', CardStatus.learning, now.subtract(const Duration(minutes: 5))),
    ];
    final queue =
        buildReviewQueue(cards, now: now, newLimit: 2, reviewLimit: 100);
    final ids = queue.map((c) => c.id).toList();

    expect(ids, contains('due_review'));
    expect(ids, contains('due_learn'));
    expect(ids, isNot(contains('future_review')));
    expect(ids.where((i) => i.startsWith('new')).length, 2);
  });

  test('학습/relearning 카드가 신규·복습보다 앞에 온다', () {
    final cards = [
      card('new1', CardStatus.newCard, now),
      card('review1', CardStatus.review, now.subtract(const Duration(hours: 1))),
      card('learn1', CardStatus.learning, now.subtract(const Duration(minutes: 5))),
    ];
    final queue =
        buildReviewQueue(cards, now: now, newLimit: 10, reviewLimit: 10);
    expect(queue.first.id, 'learn1');
  });

  test('큐가 비면 빈 리스트', () {
    final queue =
        buildReviewQueue([], now: now, newLimit: 10, reviewLimit: 10);
    expect(queue, isEmpty);
  });
}
