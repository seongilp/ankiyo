import 'package:uuid/uuid.dart';
import '../apkg/anki_db.dart';
import '../srs/card_state.dart';
import 'deck_repository.dart';
import 'models.dart';

class ImportService {
  final DeckRepository _repo;
  final Uuid _uuid;
  ImportService(this._repo, {this._uuid = const Uuid()});

  /// 파싱된 덱/카드를 저장한다. 카드가 있는 덱만 저장하고, 저장한 Deck 목록을 반환.
  Future<List<Deck>> importParsed({
    required List<ParsedDeck> decks,
    required List<ParsedCard> cards,
    required DateTime now,
  }) async {
    final byAnkiId = <int, List<ParsedCard>>{};
    for (final c in cards) {
      byAnkiId.putIfAbsent(c.deckAnkiId, () => []).add(c);
    }

    final saved = <Deck>[];
    for (final pd in decks) {
      final deckCards = byAnkiId[pd.ankiId];
      if (deckCards == null || deckCards.isEmpty) continue;

      final deck = Deck(id: _uuid.v4(), name: pd.name, importedAt: now);
      final studyCards = deckCards
          .map((pc) => StudyCard(
                id: _uuid.v4(),
                deckId: deck.id,
                frontHtml: pc.frontHtml,
                backHtml: pc.backHtml,
                isCloze: pc.isCloze,
                state: CardState.create(now),
              ))
          .toList();
      await _repo.saveDeck(deck, studyCards);
      saved.add(deck);
    }
    return saved;
  }
}
