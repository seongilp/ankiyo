import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../storage/deck_repository.dart';
import '../storage/models.dart';
import '../storage/review_log.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Future<_StatsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_StatsData> _load() async {
    final log = context.read<ReviewLogStore>();
    final repo = context.read<DeckRepository>();
    final since = DateTime.now().subtract(const Duration(days: 30));
    final entries = await log.since(_dayStart(since));
    final decks = await repo.getDecks();
    return _StatsData(entries: entries, decks: decks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D29),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D29),
        foregroundColor: Colors.white,
        title: const Text('통계'),
      ),
      body: FutureBuilder<_StatsData>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          final data = snap.data!;
          if (data.entries.isEmpty) {
            return const _Empty();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _Summary(data: data),
              const SizedBox(height: 28),
              const _SectionLabel('최근 30일'),
              const SizedBox(height: 12),
              _DailyBars(data: data),
              const SizedBox(height: 28),
              const _SectionLabel('덱별 학습량'),
              const SizedBox(height: 12),
              ..._byDeck(data),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _byDeck(_StatsData data) {
    final counts = <String, int>{};
    for (final e in data.entries) {
      counts[e.deckId] = (counts[e.deckId] ?? 0) + 1;
    }
    final deckNames = {for (final d in data.decks) d.id: d.name};
    final rows = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (rows.isEmpty) {
      return [
        Text('아직 없어요',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
      ];
    }
    return rows
        .map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DeckCountRow(
                  name: deckNames[r.key] ?? '(삭제된 덱)', count: r.value),
            ))
        .toList();
  }
}

class _StatsData {
  final List<ReviewLogEntry> entries;
  final List<Deck> decks;
  const _StatsData({required this.entries, required this.decks});
}

DateTime _dayStart(DateTime t) => DateTime(t.year, t.month, t.day);

class _Summary extends StatelessWidget {
  final _StatsData data;
  const _Summary({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = _dayStart(now);
    final weekStart = todayStart.subtract(const Duration(days: 6));
    final today = data.entries.where((e) => !e.at.isBefore(todayStart)).length;
    final week = data.entries.where((e) => !e.at.isBefore(weekStart)).length;
    final streak = _streak(data.entries, now);
    return Row(children: [
      _Stat(label: '오늘', value: '$today', suffix: '장'),
      const SizedBox(width: 10),
      _Stat(label: '7일', value: '$week', suffix: '장'),
      const SizedBox(width: 10),
      _Stat(label: '연속', value: '$streak', suffix: '일'),
    ]);
  }

  int _streak(List<ReviewLogEntry> entries, DateTime now) {
    if (entries.isEmpty) return 0;
    final days = <String>{};
    for (final e in entries) {
      final d = _dayStart(e.at);
      days.add('${d.year}-${d.month}-${d.day}');
    }
    var streak = 0;
    var cursor = _dayStart(now);
    while (true) {
      final key = '${cursor.year}-${cursor.month}-${cursor.day}';
      if (!days.contains(key)) {
        if (streak == 0 && cursor == _dayStart(now)) {
          cursor = cursor.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  const _Stat(
      {required this.label, required this.value, required this.suffix});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5),
                  children: [
                    TextSpan(text: value),
                    TextSpan(
                        text: ' $suffix',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _DailyBars extends StatelessWidget {
  final _StatsData data;
  const _DailyBars({required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final counts = <int, int>{};
    for (final e in data.entries) {
      final delta = _dayStart(now).difference(_dayStart(e.at)).inDays;
      if (delta >= 0 && delta < 30) {
        counts[delta] = (counts[delta] ?? 0) + 1;
      }
    }
    final max = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 110,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(30, (i) {
                final dayDelta = 29 - i;
                final c = counts[dayDelta] ?? 0;
                final h = max == 0 ? 0.0 : (c / max) * 100.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: h.clamp(c == 0 ? 0 : 2, 100.0),
                          decoration: BoxDecoration(
                            color: c == 0
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('30일 전',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11)),
              Text('오늘',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeckCountRow extends StatelessWidget {
  final String name;
  final int count;
  const _DeckCountRow({required this.name, required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600))),
        Text('$count장',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.7),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ));
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.bar_chart_rounded,
                  size: 40, color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            const Text('아직 학습 기록이 없어요',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '카드를 한 장이라도 풀면\n이곳에 매일 학습량이 쌓여요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
