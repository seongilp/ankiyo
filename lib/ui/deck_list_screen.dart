import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../srs/scheduler.dart';
import '../storage/deck_repository.dart';
import 'controllers/deck_list_controller.dart';
import 'controllers/review_controller.dart';
import 'controllers/settings_controller.dart';
import 'import_screen.dart';
import 'review_screen.dart';
import 'settings_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DeckListController>();
    return Scaffold(
      appBar: AppBar(
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
      floatingActionButton: c.summaries.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openImport,
              elevation: 0,
              icon: const Icon(Icons.add_rounded),
              label: const Text('덱 가져오기'),
            ),
      body: c.loading
          ? const Center(child: CircularProgressIndicator())
          : c.summaries.isEmpty
              ? _EmptyState(onImport: _openImport)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: c.summaries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _DeckCard(
                    summary: c.summaries[i],
                    onStudy: () => _study(c.summaries[i].deck.id),
                    onDelete: () => _confirmDelete(c, c.summaries[i]),
                  ),
                ),
    );
  }

  void _study(String deckId) {
    final repo = context.read<DeckRepository>();
    final settings = context.read<SettingsController>().settings;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => ReviewController(
            repo: repo,
            scheduler: const Scheduler(),
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
  final VoidCallback onDelete;
  const _DeckCard(
      {required this.summary, required this.onStudy, required this.onDelete});

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
                    const SizedBox(height: 12),
                    Row(children: [
                      _Stat(
                        label: hasDue ? '오늘 ${summary.due}장' : '오늘 학습 완료',
                        emphasized: hasDue,
                      ),
                      const SizedBox(width: 8),
                      _Stat(label: '총 ${summary.total}장'),
                    ]),
                  ],
                ),
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
  final VoidCallback onImport;
  const _EmptyState({required this.onImport});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(Icons.style_outlined,
                  size: 40, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text('아직 덱이 없어요',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Anki에서 내보낸 .apkg 파일을 가져와\n간격 반복으로 공부를 시작하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, height: 1.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.add_rounded),
              label: const Text('덱 가져오기'),
            ),
          ],
        ),
      ),
    );
  }
}
