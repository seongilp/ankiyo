enum CardStatus { newCard, learning, review, relearning }

enum Rating { again, hard, good, easy }

class CardState {
  final CardStatus status;
  final DateTime due;
  final double intervalDays;
  final double easeFactor;
  final int reps;
  final int lapses;
  final int learningStepIndex;

  const CardState({
    required this.status,
    required this.due,
    required this.intervalDays,
    required this.easeFactor,
    required this.reps,
    required this.lapses,
    required this.learningStepIndex,
  });

  factory CardState.create(DateTime now) => CardState(
        status: CardStatus.newCard,
        due: now,
        intervalDays: 0,
        easeFactor: 2.5,
        reps: 0,
        lapses: 0,
        learningStepIndex: 0,
      );

  CardState copyWith({
    CardStatus? status,
    DateTime? due,
    double? intervalDays,
    double? easeFactor,
    int? reps,
    int? lapses,
    int? learningStepIndex,
  }) =>
      CardState(
        status: status ?? this.status,
        due: due ?? this.due,
        intervalDays: intervalDays ?? this.intervalDays,
        easeFactor: easeFactor ?? this.easeFactor,
        reps: reps ?? this.reps,
        lapses: lapses ?? this.lapses,
        learningStepIndex: learningStepIndex ?? this.learningStepIndex,
      );
}
