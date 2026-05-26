import 'package:flutter/foundation.dart';
import '../../srs/card_state.dart';
import '../../storage/deck_repository.dart';
import '../../storage/models.dart';

class DeckSummary {
  final Deck deck;
  final int total;
  final int due; // 오늘 학습/복습 대상 + 신규
  const DeckSummary(
      {required this.deck, required this.total, required this.due});
}

class DeckListController extends ChangeNotifier {
  final DeckRepository repo;
  final DateTime Function() clock;
  DeckListController(this.repo, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  List<DeckSummary> summaries = [];
  bool loading = true;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    final decks = await repo.getDecks();
    final now = clock();
    final result = <DeckSummary>[];
    for (final d in decks) {
      final cards = await repo.getCards(d.id);
      final due = cards
          .where((c) =>
              c.state.status == CardStatus.newCard ||
              !c.state.due.isAfter(now))
          .length;
      result.add(DeckSummary(deck: d, total: cards.length, due: due));
    }
    summaries = result;
    loading = false;
    notifyListeners();
  }

  Future<void> delete(String deckId) async {
    await repo.deleteDeck(deckId);
    await load();
  }
}
