import 'package:flutter/foundation.dart';
import '../../srs/card_state.dart';
import '../../srs/scheduler.dart';
import '../../storage/deck_repository.dart';
import '../../storage/models.dart';
import '../../study/review_queue.dart';

class ReviewController extends ChangeNotifier {
  final DeckRepository repo;
  final Scheduler scheduler;
  final String deckId;
  final int newLimit;
  final int reviewLimit;
  final DateTime Function() clock;

  ReviewController({
    required this.repo,
    required this.scheduler,
    required this.deckId,
    required this.newLimit,
    required this.reviewLimit,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  List<StudyCard> _queue = [];
  int _index = 0;
  bool _showingBack = false;
  bool _loading = true;

  bool get loading => _loading;
  bool get showingBack => _showingBack;
  bool get isDone => _index >= _queue.length;
  int get remaining => _queue.length - _index;
  int get total => _queue.length;
  int get reviewed => _index;
  double get progress => _queue.isEmpty ? 1 : _index / _queue.length;
  StudyCard? get current => isDone ? null : _queue[_index];

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    final cards = await repo.getCards(deckId);
    _queue = buildReviewQueue(cards,
        now: clock(), newLimit: newLimit, reviewLimit: reviewLimit);
    _index = 0;
    _showingBack = false;
    _loading = false;
    notifyListeners();
  }

  void reveal() {
    _showingBack = true;
    notifyListeners();
  }

  /// 등급 평가 후 다음 카드로.
  Future<void> rate(Rating rating) async {
    final card = current;
    if (card == null) return;
    final newState = scheduler.review(card.state, rating, clock());
    await repo.updateCard(card.withState(newState));
    _index += 1;
    _showingBack = false;
    notifyListeners();
  }

  /// 버튼 라벨용: 이 등급을 주면 다음 복습이 언제인지 사람이 읽는 문자열.
  String previewLabel(Rating rating) {
    final card = current;
    if (card == null) return '';
    final s = scheduler.review(card.state, rating, clock());
    final d = s.due.difference(clock());
    if (d.inDays >= 1) return '${d.inDays}일';
    if (d.inMinutes >= 1) return '${d.inMinutes}분';
    return '곧';
  }
}
