import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../srs/card_state.dart';
import 'controllers/review_controller.dart';
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
      appBar: AppBar(title: Text('복습 (남은 카드 ${c.remaining})')),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (e) => _onKey(e, c),
        child: _body(context, c),
      ),
    );
  }

  Widget _body(BuildContext context, ReviewController c) {
    if (c.loading) return const Center(child: CircularProgressIndicator());
    if (c.isDone) {
      return const Center(
          child: Text('오늘 학습 완료! 🎉', style: TextStyle(fontSize: 24)));
    }
    final card = c.current!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Expanded(
              child: Center(
                  child: CardView(
                      html: c.showingBack ? card.backHtml : card.frontHtml))),
          const SizedBox(height: 16),
          if (!c.showingBack)
            FilledButton(
              onPressed: c.reveal,
              child: const Text('정답 보기 (Space)'),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _rateButton(c, Rating.again, '다시', Colors.red),
                _rateButton(c, Rating.hard, '어려움', Colors.orange),
                _rateButton(c, Rating.good, '좋음', Colors.green),
                _rateButton(c, Rating.easy, '쉬움', Colors.blue),
              ],
            ),
        ],
      ),
    );
  }

  Widget _rateButton(ReviewController c, Rating r, String label, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => c.rate(r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label),
              Text(c.previewLabel(r), style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
