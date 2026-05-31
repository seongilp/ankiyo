import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../srs/card_state.dart';
import 'controllers/review_controller.dart';
import 'format_due.dart';
import 'widgets/card_view.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReviewController>().load();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent e, ReviewController c) {
    if (e is! KeyDownEvent) return;
    if (!c.showingBack && e.logicalKey == LogicalKeyboardKey.space) {
      c.reveal();
    } else if (c.showingBack) {
      final map = {
        LogicalKeyboardKey.digit1: Rating.again,
        LogicalKeyboardKey.digit2: Rating.hard,
        LogicalKeyboardKey.digit3: Rating.good,
        LogicalKeyboardKey.digit4: Rating.easy,
      };
      final r = map[e.logicalKey];
      if (r != null) c.rate(r);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ReviewController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(c.drillMode ? '약한 카드 복습' : '복습'),
        bottom: c.loading || c.total == 0
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: c.progress),
                  duration: const Duration(milliseconds: 300),
                  builder: (_, v, _) => LinearProgressIndicator(
                      value: v, minHeight: 4, backgroundColor: Colors.transparent),
                ),
              ),
      ),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (e) => _onKey(e, c),
        child: SafeArea(child: _body(context, c)),
      ),
    );
  }

  Widget _body(BuildContext context, ReviewController c) {
    if (c.loading) return const Center(child: CircularProgressIndicator());
    if (c.isDone) return const _DoneView();

    final scheme = Theme.of(context).colorScheme;
    final card = c.current!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text('${c.remaining}장 남음',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                          begin: const Offset(0, 0.02), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: _CardSurface(
                key: ValueKey('${card.id}-${c.showingBack}'),
                showingBack: c.showingBack,
                front: card.frontHtml,
                back: card.backHtml,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!c.showingBack)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: c.reveal,
                child: const Text('정답 보기  ·  Space'),
              ),
            )
          else
            Row(
              children: [
                _RateButton(c, Rating.again, '다시', _RateStyle.error),
                const SizedBox(width: 8),
                _RateButton(c, Rating.hard, '어려움', _RateStyle.neutral),
                const SizedBox(width: 8),
                _RateButton(c, Rating.good, '좋음', _RateStyle.primary),
                const SizedBox(width: 8),
                _RateButton(c, Rating.easy, '쉬움', _RateStyle.tonal),
              ],
            ),
        ],
      ),
    );
  }
}

class _CardSurface extends StatelessWidget {
  final bool showingBack;
  final String front;
  final String back;
  const _CardSurface(
      {super.key,
      required this.showingBack,
      required this.front,
      required this.back});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Center(child: CardView(html: front))),
          if (showingBack) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Divider(
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                  height: 1),
            ),
            Expanded(child: Center(child: CardView(html: back))),
          ],
        ],
      ),
    );
  }
}

enum _RateStyle { error, neutral, primary, tonal }

class _RateButton extends StatelessWidget {
  final ReviewController controller;
  final Rating rating;
  final String label;
  final _RateStyle style;
  const _RateButton(this.controller, this.rating, this.label, this.style);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    late final Color bg;
    late final Color fg;
    BorderSide side = BorderSide.none;
    switch (style) {
      case _RateStyle.error:
        bg = scheme.errorContainer;
        fg = scheme.onErrorContainer;
        break;
      case _RateStyle.neutral:
        bg = Colors.transparent;
        fg = scheme.onSurface;
        side = BorderSide(color: scheme.outlineVariant);
        break;
      case _RateStyle.primary:
        bg = scheme.primary;
        fg = scheme.onPrimary;
        break;
      case _RateStyle.tonal:
        bg = scheme.surfaceContainerHighest;
        fg = scheme.onSurface;
        break;
    }

    final preview = controller.previewLabel(rating);
    return Expanded(
      child: Material(
        color: bg,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: side,
        ),
        child: InkWell(
          onTap: () => controller.rate(rating),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(preview,
                      style: TextStyle(
                          fontSize: 11, color: fg.withValues(alpha: 0.75))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.read<ReviewController>();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(Icons.check_rounded,
                size: 44, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 24),
          Text('오늘 학습 완료!',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface)),
          const SizedBox(height: 8),
          Text('${c.total}장 풀었어요. 수고했어요 👋',
              style:
                  TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          if (c.drillMode)
            Text('약한 카드를 한 바퀴 돌았어요. 계속 반복해보세요.',
                style: TextStyle(
                    fontSize: 13, color: scheme.onSurfaceVariant))
          else
          FutureBuilder<DateTime?>(
            future: c.nextDueAtForDeck(),
            builder: (_, snap) {
              final next = snap.data;
              if (next == null) {
                return Text('다음 복습 예정 없음',
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant));
              }
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 16, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      '다음 복습 — ${formatNextDue(DateTime.now(), next)}',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context),
            child: Text(c.drillMode ? '돌아가기' : '덱 목록으로'),
          ),
        ],
      ),
    );
  }
}
