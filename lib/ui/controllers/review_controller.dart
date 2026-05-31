import 'package:flutter/foundation.dart';
import '../../srs/card_state.dart';
import '../../srs/scheduler.dart';
import '../../storage/deck_repository.dart';
import '../../storage/models.dart';
import '../../storage/review_log.dart';
import '../../study/review_queue.dart';

class ReviewController extends ChangeNotifier {
  final DeckRepository repo;
  final Scheduler scheduler;
  final ReviewLogStore? log;
  final String? deckId;
  final int newLimit;
  final int reviewLimit;
  final DateTime Function() clock;

  /// 드릴 모드: 약한 카드 모음을 반복학습. SRS 일정 변경 없이 로그만 남김.
  final bool drillMode;
  final Set<String>? drillCardIds;

  ReviewController({
    required this.repo,
    required this.scheduler,
    this.deckId,
    required this.newLimit,
    required this.reviewLimit,
    this.log,
    this.drillMode = false,
    this.drillCardIds,
    DateTime Function()? clock,
  })  : assert(deckId != null || drillMode,
            'deckId 또는 drillMode 중 하나는 지정해야 함'),
        clock = clock ?? DateTime.now;

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
    if (drillMode) {
      final ids = drillCardIds ?? const <String>{};
      final cards = await repo.getCardsByIds(ids);
      cards.shuffle();
      _queue = cards;
    } else {
      final cards = await repo.getCards(deckId!);
      _queue = buildReviewQueue(cards,
          now: clock(), newLimit: newLimit, reviewLimit: reviewLimit);
    }
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
    final now = clock();
    if (!drillMode) {
      final newState = scheduler.review(card.state, rating, now);
      await repo.updateCard(card.withState(newState));
    }
    await log?.append(ReviewLogEntry(
        cardId: card.id, deckId: card.deckId, rating: rating, at: now));
    _index += 1;
    _showingBack = false;
    notifyListeners();
  }

  /// 세션이 끝났을 때, 덱 전체에서 가장 빠른 다음 복습 시각. 드릴 모드에선 null.
  Future<DateTime?> nextDueAtForDeck() async {
    if (drillMode || deckId == null) return null;
    final cards = await repo.getCards(deckId!);
    final now = clock();
    DateTime? earliest;
    for (final c in cards) {
      if (c.state.due.isAfter(now)) {
        if (earliest == null || c.state.due.isBefore(earliest)) {
          earliest = c.state.due;
        }
      }
    }
    return earliest;
  }

  /// 버튼 라벨용: 이 등급을 주면 다음 복습이 언제인지 사람이 읽는 문자열.
  String previewLabel(Rating rating) {
    if (drillMode) return '';
    final card = current;
    if (card == null) return '';
    final s = scheduler.review(card.state, rating, clock());
    final d = s.due.difference(clock());
    if (d.inDays >= 1) return '${d.inDays}일';
    if (d.inHours >= 1) return '${d.inHours}시간';
    if (d.inMinutes >= 1) return '${d.inMinutes}분';
    return '곧';
  }
}
