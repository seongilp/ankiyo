import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../srs/scheduler.dart';
import '../storage/deck_repository.dart';
import '../llm/word_extractor.dart';
import '../storage/review_log.dart';
import 'format_due.dart';
import 'controllers/create_deck_controller.dart';
import 'controllers/deck_list_controller.dart';
import 'controllers/review_controller.dart';
import 'controllers/settings_controller.dart';
import 'create_deck_screen.dart';
import 'import_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});
  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeckListController>().load();
    });
  }

  Future<void> _openImport() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ImportScreen()));
    if (mounted) context.read<DeckListController>().load();
  }

  void _openStats() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const StatsScreen()));
    if (mounted) context.read<DeckListController>().load();
  }

  Future<void> _openDrill() async {
    final repo = context.read<DeckRepository>();
    final log = context.read<ReviewLogStore>();
    final ids = await log.weakCardIds(now: DateTime.now());
    if (!mounted) return;
    if (ids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최근 7일 안에 다시·어려움으로 표시한 카드가 없어요')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ReviewController(
            repo: repo,
            scheduler: const Scheduler(),
            log: log,
            drillMode: true,
            drillCardIds: ids,
            newLimit: 0,
            reviewLimit: 0,
          ),
          child: const ReviewScreen(),
        ),
      ),
    );
    if (mounted) {
      context.read<DeckListController>().load();
    }
  }

  Future<void> _openCreate() async {
    final repo = context.read<DeckRepository>();
    final extractor = context.read<WordExtractor>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) =>
              CreateDeckController(repo: repo, extractor: extractor),
          child: const CreateDeckScreen(),
        ),
      ),
    );
    if (mounted) context.read<DeckListController>().load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeckListController>();
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D29),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D29),
        foregroundColor: Colors.white,
        title: const Text('ankiyo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: '설정',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          const SizedBox(width: 4),
        ],
      ),
      bottomNavigationBar: c.summaries.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(children: [
                  Expanded(
                    child: _BottomAction(
                      icon: Icons.note_add_rounded,
                      label: '만들기',
                      onTap: _openCreate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BottomAction(
                      icon: Icons.file_upload_rounded,
                      label: '가져오기',
                      onTap: _openImport,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BottomAction(
                      icon: Icons.replay_rounded,
                      label: '복습',
                      badge: c.weakCount > 0 ? '${c.weakCount}' : null,
                      onTap: _openDrill,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BottomAction(
                      icon: Icons.bar_chart_rounded,
                      label: '통계',
                      onTap: _openStats,
                    ),
                  ),
                ]),
              ),
            ),
      body: c.loading
          ? const Center(child: CircularProgressIndicator())
          : c.summaries.isEmpty
              ? _EmptyState(onCreate: _openCreate, onImport: _openImport)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: c.summaries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _DeckCard(
                    summary: c.summaries[i],
                    onStudy: () => _study(c.summaries[i].deck.id),
                    onRename: () => _renameDeck(c, c.summaries[i]),
                    onDelete: () => _confirmDelete(c, c.summaries[i]),
                  ),
                ),
    );
  }

  void _study(String deckId) {
    final repo = context.read<DeckRepository>();
    final log = context.read<ReviewLogStore>();
    final settings = context.read<SettingsController>().settings;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ReviewController(
            repo: repo,
            scheduler: const Scheduler(),
            log: log,
            deckId: deckId,
            newLimit: settings.newLimit,
            reviewLimit: settings.reviewLimit,
          ),
          child: const ReviewScreen(),
        ),
      ),
    ).then((_) {
      if (mounted) context.read<DeckListController>().load();
    });
  }

  Future<void> _renameDeck(DeckListController c, DeckSummary s) async {
    final ctrl = TextEditingController(text: s.deck.name);
    final ok = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('덱 이름 변경'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '덱 이름',
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('저장')),
        ],
      ),
    );
    if (ok != null && ok.isNotEmpty && ok != s.deck.name) {
      await c.rename(s.deck.id, ok);
    }
  }

  Future<void> _confirmDelete(DeckListController c, DeckSummary s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('덱 삭제'),
        content: Text('"${s.deck.name}" 덱과 학습 진도를 삭제할까요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) c.delete(s.deck.id);
  }
}

class _DeckCard extends StatelessWidget {
  final DeckSummary summary;
  final VoidCallback onStudy;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _DeckCard({
    required this.summary,
    required this.onStudy,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasDue = summary.due > 0;
    return Card(
      child: InkWell(
        onTap: onStudy,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.deck.name,
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3),
                    ),
                    if (summary.studiedToday > 0) ...[
                      const SizedBox(height: 4),
                      Text('오늘 ${summary.studiedToday}장 풀었어요',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 12),
                    Row(children: [
                      _Stat(
                        label: hasDue
                            ? '지금 ${summary.due}장'
                            : summary.nextDueAt != null
                                ? '다음 ${formatNextDue(DateTime.now(), summary.nextDueAt!)}'
                                : '오늘 학습 완료',
                        emphasized: hasDue,
                      ),
                      const SizedBox(width: 8),
                      _Stat(label: '총 ${summary.total}장'),
                    ]),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                color: scheme.onSurfaceVariant,
                tooltip: '이름 변경',
                onPressed: onRename,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: scheme.onSurfaceVariant,
                tooltip: '삭제',
                onPressed: onDelete,
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    final bg = Colors.white.withValues(alpha: 0.06);
    final border = Border.all(color: Colors.white.withValues(alpha: 0.12));
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: border,
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 22, color: fg),
                  if (badge != null)
                    Positioned(
                      right: -10,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        constraints: const BoxConstraints(minWidth: 16),
                        alignment: Alignment.center,
                        child: Text(
                          badge!,
                          style: const TextStyle(
                              color: Color(0xFF1A1D29),
                              fontSize: 10,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final bool emphasized;
  const _Stat({required this.label, this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = emphasized ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = emphasized ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onImport;
  const _EmptyState({required this.onCreate, required this.onImport});

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
              child: Icon(Icons.style_outlined,
                  size: 40, color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 24),
            const Text('아직 덱이 없어요',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              '새 덱을 만들거나\nAnki에서 내보낸 .apkg 파일을 가져오세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 28),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.note_add_rounded),
                    label: const Text('새로 만들기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.file_upload_rounded),
                    label: const Text('가져오기'),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
