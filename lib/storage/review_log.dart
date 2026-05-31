import 'package:sembast/sembast.dart';
import '../srs/card_state.dart';

class ReviewLogEntry {
  final String cardId;
  final String deckId;
  final Rating rating;
  final DateTime at;

  const ReviewLogEntry({
    required this.cardId,
    required this.deckId,
    required this.rating,
    required this.at,
  });

  Map<String, Object?> toMap() => {
        'cardId': cardId,
        'deckId': deckId,
        'rating': rating.name,
        'at': at.toIso8601String(),
      };

  factory ReviewLogEntry.fromMap(Map<String, Object?> m) => ReviewLogEntry(
        cardId: m['cardId'] as String,
        deckId: m['deckId'] as String,
        rating: Rating.values.byName(m['rating'] as String),
        at: DateTime.parse(m['at'] as String),
      );
}

class ReviewLogStore {
  final Database _db;
  final _store = intMapStoreFactory.store('review_log');
  ReviewLogStore(this._db);

  Future<void> append(ReviewLogEntry e) => _store.add(_db, e.toMap());

  Future<List<ReviewLogEntry>> all() async {
    final recs = await _store.find(_db,
        finder: Finder(sortOrders: [SortOrder('at')]));
    return recs.map((r) => ReviewLogEntry.fromMap(r.value)).toList();
  }

  Future<List<ReviewLogEntry>> since(DateTime from) async {
    final recs = await _store.find(_db,
        finder: Finder(
          filter: Filter.greaterThanOrEquals('at', from.toIso8601String()),
          sortOrders: [SortOrder('at')],
        ));
    return recs.map((r) => ReviewLogEntry.fromMap(r.value)).toList();
  }

  /// 오늘 풀어둔 평가 횟수(특정 덱 한정 가능).
  Future<int> countToday({String? deckId, required DateTime now}) async {
    final dayStart = DateTime(now.year, now.month, now.day);
    final recs = await _store.find(_db,
        finder: Finder(
          filter: Filter.greaterThanOrEquals('at', dayStart.toIso8601String()),
        ));
    if (deckId == null) return recs.length;
    return recs.where((r) => r.value['deckId'] == deckId).length;
  }

  /// 지정 기간 안에서, 카드별 최신 평가가 Again 또는 Hard인 카드 id 모음.
  Future<Set<String>> weakCardIds({
    required DateTime now,
    Duration window = const Duration(days: 7),
  }) async {
    final from = now.subtract(window);
    final entries = await since(from);
    final latest = <String, ReviewLogEntry>{};
    for (final e in entries) {
      final existing = latest[e.cardId];
      if (existing == null || e.at.isAfter(existing.at)) {
        latest[e.cardId] = e;
      }
    }
    return latest.entries
        .where((kv) =>
            kv.value.rating == Rating.again ||
            kv.value.rating == Rating.hard)
        .map((kv) => kv.key)
        .toSet();
  }
}
