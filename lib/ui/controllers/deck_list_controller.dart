import 'package:flutter/foundation.dart';
import '../../storage/deck_repository.dart';
import '../../storage/models.dart';
import '../../storage/review_log.dart';
import '../../storage/settings_store.dart';
import '../../study/review_queue.dart';

class DeckSummary {
  final Deck deck;
  final int total;
  final int due; // 오늘 큐에서 지금 풀 수 있는 장수 (일일 한도 적용)
  final int studiedToday; // 오늘 이 덱에서 풀어둔 누적 장수
  final DateTime? nextDueAt; // due == 0 일 때 가장 빠른 다음 복습 시각
  const DeckSummary({
    required this.deck,
    required this.total,
    required this.due,
    required this.studiedToday,
    this.nextDueAt,
  });
}

class DeckListController extends ChangeNotifier {
  final DeckRepository repo;
  final SettingsStore settingsStore;
  final ReviewLogStore log;
  final DateTime Function() clock;
  DeckListController(this.repo, this.settingsStore, this.log,
      {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  List<DeckSummary> summaries = [];
  int weakCount = 0;
  bool loading = true;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    final decks = await repo.getDecks();
    final settings = await settingsStore.load();
    final now = clock();
    final result = <DeckSummary>[];
    for (final d in decks) {
      final cards = await repo.getCards(d.id);
      final queue = buildReviewQueue(cards,
          now: now,
          newLimit: settings.newLimit,
          reviewLimit: settings.reviewLimit);
      final due = queue.length;
      final studiedToday = await log.countToday(deckId: d.id, now: now);
      DateTime? next;
      if (due == 0) {
        for (final c in cards) {
          if (c.state.due.isAfter(now)) {
            if (next == null || c.state.due.isBefore(next)) {
              next = c.state.due;
            }
          }
        }
      }
      result.add(DeckSummary(
        deck: d,
        total: cards.length,
        due: due,
        studiedToday: studiedToday,
        nextDueAt: next,
      ));
    }
    summaries = result;
    weakCount = (await log.weakCardIds(now: now)).length;
    loading = false;
    notifyListeners();
  }

  Future<void> delete(String deckId) async {
    await repo.deleteDeck(deckId);
    await load();
  }

  Future<void> rename(String deckId, String newName) async {
    await repo.renameDeck(deckId, newName);
    await load();
  }
}
