import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/create_deck_controller.dart';
import 'controllers/deck_list_controller.dart';
import 'review_extracted_screen.dart';

class CreateDeckScreen extends StatefulWidget {
  const CreateDeckScreen({super.key});
  @override
  State<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends State<CreateDeckScreen> {
  final _nameCtrl = TextEditingController();
  final _textCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final c = context.read<CreateDeckController>();
    final name = _nameCtrl.text.trim();
    final passage = _textCtrl.text;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('덱 이름을 입력해 주세요')),
      );
      return;
    }
    if (passage.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본문을 붙여넣어 주세요')),
      );
      return;
    }
    await c.analyze(passage);
    if (!mounted) return;
    if (c.stage == CreateDeckStage.review) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<CreateDeckController>.value(
            value: c,
            child: ReviewExtractedScreen(deckName: name),
          ),
        ),
      );
      if (mounted) context.read<DeckListController>().load();
    } else if (c.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(c.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CreateDeckController>();
    final analyzing = c.stage == CreateDeckStage.analyzing;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D29),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D29),
        foregroundColor: Colors.white,
        title: const Text('새로 만들기'),
      ),
      body: Stack(children: [
        AbsorbPointer(
          absorbing: analyzing,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Label('덱 이름'),
                const SizedBox(height: 8),
                _DarkTextField(
                  controller: _nameCtrl,
                  hint: '예: 수능 영어 Unit 3 / TOEFL 빈출 단어',
                  maxLines: 1,
                ),
                const SizedBox(height: 20),
                const _Label('본문 또는 단어 목록'),
                const SizedBox(height: 8),
                _DarkTextField(
                  controller: _textCtrl,
                  hint:
                      '세 가지 방식 모두 OK:\n\n① 영어 본문 그대로 — 핵심 단어를 자동 추출해요.\n② 한 줄에 단어만 — 한국어 뜻은 알아서 채워요.\n③ 한 줄에 "단어 / 뜻" — 그대로 카드로 만들어요.',
                  maxLines: 16,
                  minLines: 12,
                ),
                const SizedBox(height: 8),
                Text(
                  '※ 길어도 괜찮아요. 중요 단어 위주로 20~40장 정도 만들어요.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ),
        ),
        if (analyzing) const _AnalyzingOverlay(),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            onPressed: analyzing ? null : _submit,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('만들기'),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.7),
          letterSpacing: 0.2,
        ),
      );
}

class _DarkTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int? maxLines;
  final int? minLines;
  const _DarkTextField({
    required this.controller,
    required this.hint,
    this.maxLines,
    this.minLines,
  });
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.35), height: 1.5),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
        ),
      ),
    );
  }
}

class _AnalyzingOverlay extends StatefulWidget {
  const _AnalyzingOverlay();
  @override
  State<_AnalyzingOverlay> createState() => _AnalyzingOverlayState();
}

class _AnalyzingOverlayState extends State<_AnalyzingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _orbit;
  int _msgIndex = 0;
  static const _messages = [
    '본문을 읽고 있어요',
    '핵심 단어를 고르고 있어요',
    '뜻과 예문을 정리하고 있어요',
    '카드로 다듬는 중이에요',
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _orbit =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    _cycleMessage();
  }

  void _cycleMessage() {
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);
      _cycleMessage();
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1A1D29).withValues(alpha: 0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulse, _orbit]),
                builder: (_, _) => CustomPaint(
                  painter:
                      _OrbitPainter(pulse: _pulse.value, orbit: _orbit.value),
                ),
              ),
            ),
            const SizedBox(height: 28),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Text(
                _messages[_msgIndex],
                key: ValueKey(_msgIndex),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '잠시만 기다려 주세요',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double pulse;
  final double orbit;
  _OrbitPainter({required this.pulse, required this.orbit});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(c, maxR * 0.95, ringPaint);
    canvas.drawCircle(c, maxR * 0.65, ringPaint);

    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(c, 22 + pulse * 8, glow);

    final coreR = 12 + pulse * 5;
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 + pulse * 0.15);
    canvas.drawCircle(c, coreR, corePaint);

    final dotPaint = Paint()..color = Colors.white;
    for (var i = 0; i < 3; i++) {
      final a = orbit * 2 * math.pi + i * (2 * math.pi / 3);
      final r = maxR * 0.92;
      final p = c + Offset(r * math.cos(a), r * math.sin(a));
      canvas.drawCircle(p, 3.5, dotPaint);
    }
    final softDot = Paint()..color = Colors.white.withValues(alpha: 0.65);
    for (var i = 0; i < 2; i++) {
      final a = -orbit * 2 * math.pi + i * math.pi;
      final r = maxR * 0.62;
      final p = c + Offset(r * math.cos(a), r * math.sin(a));
      canvas.drawCircle(p, 2.5, softDot);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) =>
      old.pulse != pulse || old.orbit != orbit;
}
