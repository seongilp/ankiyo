import '../srs/card_state.dart';
import '../storage/models.dart';

/// 오늘 학습 큐: 만기된 학습/relearning → 만기된 복습 → 신규(한도 내) 순서.
List<StudyCard> buildReviewQueue(
  List<StudyCard> cards, {
  required DateTime now,
  required int newLimit,
  required int reviewLimit,
}) {
  bool due(StudyCard c) => !c.state.due.isAfter(now);

  final learning = cards
      .where((c) =>
          (c.state.status == CardStatus.learning ||
              c.state.status == CardStatus.relearning) &&
          due(c))
      .toList()
    ..sort((a, b) => a.state.due.compareTo(b.state.due));

  final reviews = cards
      .where((c) => c.state.status == CardStatus.review && due(c))
      .toList()
    ..sort((a, b) => a.state.due.compareTo(b.state.due));

  final news =
      cards.where((c) => c.state.status == CardStatus.newCard).toList();

  return [
    ...learning,
    ...reviews.take(reviewLimit),
    ...news.take(newLimit),
  ];
}
