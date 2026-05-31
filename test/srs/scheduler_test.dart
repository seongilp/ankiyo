import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/srs/scheduler.dart';

void main() {
  final now = DateTime.utc(2026, 1, 1, 9);
  const sched = Scheduler(); // 기본 config

  group('신규/학습 카드 - 사다리 [10분, 10시간, 2일, 7일]', () {
    test('Again은 첫 스텝(10분 뒤)으로 리셋한다', () {
      final s = CardState.create(now).copyWith(
          status: CardStatus.learning, learningStepIndex: 2);
      final r = sched.review(s, Rating.again, now);
      expect(r.status, CardStatus.learning);
      expect(r.learningStepIndex, 0);
      expect(r.due, now.add(const Duration(minutes: 10)));
    });

    test('새 카드 Good → 10시간 뒤(저녁) 복습', () {
      final s = CardState.create(now);
      final r = sched.review(s, Rating.good, now);
      expect(r.status, CardStatus.learning);
      expect(r.learningStepIndex, 1);
      expect(r.due, now.add(const Duration(hours: 10)));
    });

    test('저녁 Good → 2일 뒤 복습', () {
      final s = CardState.create(now).copyWith(
          status: CardStatus.learning, learningStepIndex: 1);
      final r = sched.review(s, Rating.good, now);
      expect(r.learningStepIndex, 2);
      expect(r.due, now.add(const Duration(days: 2)));
    });

    test('2일 후 Good → 7일 뒤 복습', () {
      final s = CardState.create(now).copyWith(
          status: CardStatus.learning, learningStepIndex: 2);
      final r = sched.review(s, Rating.good, now);
      expect(r.learningStepIndex, 3);
      expect(r.due, now.add(const Duration(days: 7)));
    });

    test('7일 후 Good → 졸업(14일 간격)', () {
      final s = CardState.create(now).copyWith(
          status: CardStatus.learning, learningStepIndex: 3);
      final r = sched.review(s, Rating.good, now);
      expect(r.status, CardStatus.review);
      expect(r.intervalDays, 14);
      expect(r.due, now.add(const Duration(days: 14)));
      expect(r.reps, 1);
    });

    test('Easy는 즉시 졸업(4일 간격)', () {
      final s = CardState.create(now);
      final r = sched.review(s, Rating.easy, now);
      expect(r.status, CardStatus.review);
      expect(r.intervalDays, 4);
      expect(r.due, now.add(const Duration(days: 4)));
    });
  });

  group('복습 카드', () {
    CardState reviewCard({double ivl = 10, double ease = 2.5}) =>
        CardState.create(now).copyWith(
          status: CardStatus.review,
          intervalDays: ivl,
          easeFactor: ease,
          reps: 3,
        );

    test('Good은 간격 = 간격 × ease', () {
      final r = sched.review(reviewCard(ivl: 10, ease: 2.5), Rating.good, now);
      expect(r.intervalDays, closeTo(25, 0.001)); // 10 * 2.5
      expect(r.due, now.add(const Duration(days: 25)));
      expect(r.reps, 4);
    });

    test('Hard는 간격 × 1.2, ease 감소', () {
      final r = sched.review(reviewCard(ivl: 10, ease: 2.5), Rating.hard, now);
      expect(r.intervalDays, closeTo(12, 0.001)); // 10 * 1.2
      expect(r.easeFactor, closeTo(2.35, 0.001)); // 2.5 - 0.15
    });

    test('Easy는 간격 × ease × 1.3, ease 증가', () {
      final r = sched.review(reviewCard(ivl: 10, ease: 2.5), Rating.easy, now);
      expect(r.easeFactor, closeTo(2.65, 0.001)); // 2.5 + 0.15
      expect(r.intervalDays, closeTo(34.45, 0.001)); // 10 * 2.65 * 1.3
    });

    test('Again은 lapse 처리 후 relearning으로 보낸다', () {
      final r = sched.review(reviewCard(ivl: 10, ease: 2.5), Rating.again, now);
      expect(r.status, CardStatus.relearning);
      expect(r.lapses, 1);
      expect(r.easeFactor, closeTo(2.3, 0.001)); // 2.5 - 0.20
      expect(r.due, now.add(const Duration(minutes: 10))); // relearning step
      expect(r.intervalDays, 1); // lapseFactor 0 → max(1)
    });

    test('ease는 minEase(1.3) 아래로 내려가지 않는다', () {
      final r = sched.review(reviewCard(ease: 1.3), Rating.again, now);
      expect(r.easeFactor, 1.3);
    });

    test('간격은 최소 현재+1일 보장', () {
      final r = sched.review(reviewCard(ivl: 1, ease: 1.3), Rating.hard, now);
      expect(r.intervalDays, greaterThanOrEqualTo(2)); // 1*1.2=1.2 < 2 → 2
    });
  });

  group('relearning 카드', () {
    test('Good이면 review로 복귀(최소 1일)', () {
      final s = CardState.create(now).copyWith(
          status: CardStatus.relearning, intervalDays: 1, learningStepIndex: 0);
      final r = sched.review(s, Rating.good, now);
      expect(r.status, CardStatus.review);
      expect(r.intervalDays, greaterThanOrEqualTo(1));
    });

    test('Again이면 relearning 첫 스텝 유지', () {
      final s = CardState.create(now).copyWith(
          status: CardStatus.relearning, intervalDays: 1);
      final r = sched.review(s, Rating.again, now);
      expect(r.status, CardStatus.relearning);
      expect(r.learningStepIndex, 0);
    });
  });
}
