import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/srs/card_state.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 9);

  test('CardState.create는 신규 카드 기본값을 갖는다', () {
    final s = CardState.create(now);
    expect(s.status, CardStatus.newCard);
    expect(s.due, now);
    expect(s.intervalDays, 0);
    expect(s.easeFactor, 2.5);
    expect(s.reps, 0);
    expect(s.lapses, 0);
    expect(s.learningStepIndex, 0);
  });

  test('copyWith는 새 객체를 반환하고 원본을 변경하지 않는다', () {
    final s = CardState.create(now);
    final s2 = s.copyWith(reps: 5, status: CardStatus.review);
    expect(s2.reps, 5);
    expect(s2.status, CardStatus.review);
    expect(s.reps, 0); // 원본 불변
    expect(s.status, CardStatus.newCard);
    expect(s2.easeFactor, 2.5); // 미지정 값 유지
  });
}
