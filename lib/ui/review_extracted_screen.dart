import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../llm/word_extractor.dart';
import 'controllers/create_deck_controller.dart';

class ReviewExtractedScreen extends StatelessWidget {
  final String deckName;
  const ReviewExtractedScreen({super.key, required this.deckName});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CreateDeckController>();
    final saving = c.stage == CreateDeckStage.saving;

    if (c.stage == CreateDeckStage.done) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) {
          Navigator.popUntil(context, (r) => r.isFirst);
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1A1D29),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D29),
        foregroundColor: Colors.white,
        title: Text('카드 검토 · ${c.cards.length}장'),
      ),
      body: c.cards.isEmpty
          ? const _EmptyMessage()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: c.cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _CardRow(
                index: i,
                card: c.cards[i],
                onEdit: () => _edit(context, i, c.cards[i]),
                onDelete: () => c.removeCard(i),
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: saving || c.cards.isEmpty
                ? null
                : () async {
                    await c.save(deckName);
                    if (!context.mounted) return;
                    if (c.errorMessage != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(c.errorMessage!)),
                      );
                    }
                  },
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded),
            label: Text(saving ? '저장 중…' : '${c.cards.length}장으로 덱 저장'),
          ),
        ),
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, int index, ExtractedCard card) async {
    final word = TextEditingController(text: card.word);
    final pos = TextEditingController(text: card.pos);
    final meaning = TextEditingController(text: card.meaning);
    final example = TextEditingController(text: card.example);
    final result = await showDialog<ExtractedCard>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF222637),
        title: const Text('카드 편집', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField('단어', word),
              const SizedBox(height: 10),
              _dialogField('품사', pos),
              const SizedBox(height: 10),
              _dialogField('뜻', meaning),
              const SizedBox(height: 10),
              _dialogField('예문', example, maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              ExtractedCard(
                word: word.text.trim(),
                pos: pos.text.trim(),
                meaning: meaning.text.trim(),
                example: example.text.trim(),
              ),
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result != null && context.mounted) {
      context.read<CreateDeckController>().updateCard(index, result);
    }
  }

  Widget _dialogField(String label, TextEditingController c, {int? maxLines}) {
    return TextField(
      controller: c,
      maxLines: maxLines ?? 1,
      style: const TextStyle(color: Colors.white),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  final int index;
  final ExtractedCard card;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _CardRow({
    required this.index,
    required this.card,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          card.word,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (card.pos.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(card.pos,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Text(card.meaning,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 14)),
                    if (card.example.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(card.example,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                              fontStyle: FontStyle.italic)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                color: Colors.white.withValues(alpha: 0.6),
                tooltip: '제거',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage();
  @override
  Widget build(BuildContext context) => Center(
        child: Text('카드가 모두 제거됐어요',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
      );
}
