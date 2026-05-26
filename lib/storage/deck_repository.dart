import 'package:sembast/sembast.dart';
import 'models.dart';

class DeckRepository {
  final Database _db;
  final _decks = stringMapStoreFactory.store('decks');
  final _cards = stringMapStoreFactory.store('cards');

  DeckRepository(this._db);

  Future<void> saveDeck(Deck deck, List<StudyCard> cards) async {
    await _db.transaction((txn) async {
      await _decks.record(deck.id).put(txn, deck.toMap());
      for (final c in cards) {
        await _cards.record(c.id).put(txn, c.toMap());
      }
    });
  }

  Future<List<Deck>> getDecks() async {
    final records = await _decks.find(_db,
        finder: Finder(sortOrders: [SortOrder('importedAt')]));
    return records.map((r) => Deck.fromMap(r.value)).toList();
  }

  Future<List<StudyCard>> getCards(String deckId) async {
    final records = await _cards.find(_db,
        finder: Finder(filter: Filter.equals('deckId', deckId)));
    return records.map((r) => StudyCard.fromMap(r.value)).toList();
  }

  Future<void> updateCard(StudyCard card) async {
    await _cards.record(card.id).put(_db, card.toMap());
  }

  Future<void> deleteDeck(String deckId) async {
    await _db.transaction((txn) async {
      await _decks.record(deckId).delete(txn);
      await _cards.delete(txn,
          finder: Finder(filter: Filter.equals('deckId', deckId)));
    });
  }
}
