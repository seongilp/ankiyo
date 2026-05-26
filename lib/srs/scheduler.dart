import 'card_state.dart';

class SchedulerConfig {
  final List<Duration> learningSteps;
  final List<Duration> relearningSteps;
  final double minEase;
  final double easeAgainDelta;
  final double easeHardDelta;
  final double easeEasyDelta;
  final double hardMultiplier;
  final double easyBonus;
  final int graduatingIntervalDays;
  final int easyIntervalDays;
  final double lapseNewIntervalFactor;

  const SchedulerConfig({
    this.learningSteps = const [Duration(minutes: 1), Duration(minutes: 10)],
    this.relearningSteps = const [Duration(minutes: 10)],
    this.minEase = 1.3,
    this.easeAgainDelta = -0.20,
    this.easeHardDelta = -0.15,
    this.easeEasyDelta = 0.15,
    this.hardMultiplier = 1.2,
    this.easyBonus = 1.3,
    this.graduatingIntervalDays = 1,
    this.easyIntervalDays = 4,
    this.lapseNewIntervalFactor = 0.0,
  });
}

class Scheduler {
  final SchedulerConfig config;
  const Scheduler([this.config = const SchedulerConfig()]);

  CardState review(CardState s, Rating rating, DateTime now) {
    switch (s.status) {
      case CardStatus.newCard:
      case CardStatus.learning:
        return _learning(s, rating, now);
      case CardStatus.relearning:
        return _relearning(s, rating, now);
      case CardStatus.review:
        return _review(s, rating, now);
    }
  }

  CardState _learning(CardState s, Rating rating, DateTime now) {
    final steps = config.learningSteps;
    switch (rating) {
      case Rating.again:
        return s.copyWith(
            status: CardStatus.learning,
            learningStepIndex: 0,
            intervalDays: 0,
            due: now.add(steps.first));
      case Rating.hard:
        final idx = s.learningStepIndex.clamp(0, steps.length - 1);
        return s.copyWith(
            status: CardStatus.learning,
            learningStepIndex: idx,
            intervalDays: 0,
            due: now.add(steps[idx]));
      case Rating.good:
        final nextIdx = s.learningStepIndex + 1;
        if (nextIdx >= steps.length) {
          return s.copyWith(
              status: CardStatus.review,
              intervalDays: config.graduatingIntervalDays.toDouble(),
              learningStepIndex: 0,
              reps: s.reps + 1,
              due: now.add(Duration(days: config.graduatingIntervalDays)));
        }
        return s.copyWith(
            status: CardStatus.learning,
            learningStepIndex: nextIdx,
            intervalDays: 0,
            due: now.add(steps[nextIdx]));
      case Rating.easy:
        return s.copyWith(
            status: CardStatus.review,
            intervalDays: config.easyIntervalDays.toDouble(),
            learningStepIndex: 0,
            reps: s.reps + 1,
            due: now.add(Duration(days: config.easyIntervalDays)));
    }
  }

  CardState _relearning(CardState s, Rating rating, DateTime now) {
    final steps = config.relearningSteps;
    switch (rating) {
      case Rating.again:
        return s.copyWith(learningStepIndex: 0, due: now.add(steps.first));
      case Rating.hard:
        final idx = s.learningStepIndex.clamp(0, steps.length - 1);
        return s.copyWith(due: now.add(steps[idx]));
      case Rating.good:
        final nextIdx = s.learningStepIndex + 1;
        if (nextIdx >= steps.length) {
          final ivl = s.intervalDays < 1 ? 1.0 : s.intervalDays;
          return s.copyWith(
              status: CardStatus.review,
              intervalDays: ivl,
              learningStepIndex: 0,
              due: now.add(Duration(days: ivl.round())));
        }
        return s.copyWith(
            learningStepIndex: nextIdx, due: now.add(steps[nextIdx]));
      case Rating.easy:
        final ivl = (s.intervalDays < 1 ? 1.0 : s.intervalDays) + 1;
        return s.copyWith(
            status: CardStatus.review,
            intervalDays: ivl,
            learningStepIndex: 0,
            due: now.add(Duration(days: ivl.round())));
    }
  }

  CardState _review(CardState s, Rating rating, DateTime now) {
    switch (rating) {
      case Rating.again:
        final newEase = _clampEase(s.easeFactor + config.easeAgainDelta);
        final lapsedIvl =
            _atLeast(s.intervalDays * config.lapseNewIntervalFactor, 1);
        return s.copyWith(
            status: CardStatus.relearning,
            easeFactor: newEase,
            lapses: s.lapses + 1,
            learningStepIndex: 0,
            intervalDays: lapsedIvl,
            due: now.add(config.relearningSteps.first));
      case Rating.hard:
        final newEase = _clampEase(s.easeFactor + config.easeHardDelta);
        final ivl =
            _nextIvl(s.intervalDays * config.hardMultiplier, s.intervalDays);
        return s.copyWith(
            easeFactor: newEase,
            intervalDays: ivl,
            reps: s.reps + 1,
            due: now.add(Duration(days: ivl.round())));
      case Rating.good:
        final ivl = _nextIvl(s.intervalDays * s.easeFactor, s.intervalDays);
        return s.copyWith(
            intervalDays: ivl,
            reps: s.reps + 1,
            due: now.add(Duration(days: ivl.round())));
      case Rating.easy:
        final newEase = s.easeFactor + config.easeEasyDelta;
        final ivl = _nextIvl(
            s.intervalDays * newEase * config.easyBonus, s.intervalDays);
        return s.copyWith(
            easeFactor: newEase,
            intervalDays: ivl,
            reps: s.reps + 1,
            due: now.add(Duration(days: ivl.round())));
    }
  }

  double _clampEase(double e) => e < config.minEase ? config.minEase : e;
  double _atLeast(double v, double min) => v < min ? min : v;
  double _nextIvl(double proposed, double current) =>
      proposed < current + 1 ? current + 1 : proposed;
}
