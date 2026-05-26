import '../srs/card_state.dart';

class Deck {
  final String id;
  final String name;
  final DateTime importedAt;
  const Deck({required this.id, required this.name, required this.importedAt});

  Map<String, Object?> toMap() =>
      {'id': id, 'name': name, 'importedAt': importedAt.toIso8601String()};

  factory Deck.fromMap(Map<String, Object?> m) => Deck(
        id: m['id'] as String,
        name: m['name'] as String,
        importedAt: DateTime.parse(m['importedAt'] as String),
      );
}

class StudyCard {
  final String id;
  final String deckId;
  final String frontHtml;
  final String backHtml;
  final bool isCloze;
  final CardState state;

  const StudyCard({
    required this.id,
    required this.deckId,
    required this.frontHtml,
    required this.backHtml,
    required this.isCloze,
    required this.state,
  });

  StudyCard withState(CardState s) => StudyCard(
        id: id,
        deckId: deckId,
        frontHtml: frontHtml,
        backHtml: backHtml,
        isCloze: isCloze,
        state: s,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'deckId': deckId,
        'frontHtml': frontHtml,
        'backHtml': backHtml,
        'isCloze': isCloze,
        'status': state.status.name,
        'due': state.due.toIso8601String(),
        'intervalDays': state.intervalDays,
        'easeFactor': state.easeFactor,
        'reps': state.reps,
        'lapses': state.lapses,
        'learningStepIndex': state.learningStepIndex,
      };

  factory StudyCard.fromMap(Map<String, Object?> m) => StudyCard(
        id: m['id'] as String,
        deckId: m['deckId'] as String,
        frontHtml: m['frontHtml'] as String,
        backHtml: m['backHtml'] as String,
        isCloze: m['isCloze'] as bool,
        state: CardState(
          status: CardStatus.values.byName(m['status'] as String),
          due: DateTime.parse(m['due'] as String),
          intervalDays: (m['intervalDays'] as num).toDouble(),
          easeFactor: (m['easeFactor'] as num).toDouble(),
          reps: (m['reps'] as num).toInt(),
          lapses: (m['lapses'] as num).toInt(),
          learningStepIndex: (m['learningStepIndex'] as num).toInt(),
        ),
      );
}
