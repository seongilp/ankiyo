import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../storage/settings_store.dart';
import 'controllers/settings_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SettingsController>();
    final s = c.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _SectionLabel('하루 학습량'),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                children: [
                  _LimitTile(
                    title: '신규 카드',
                    value: s.newLimit,
                    max: 100,
                    onChanged: (v) => c.update(SrsSettings(
                        newLimit: v, reviewLimit: s.reviewLimit)),
                  ),
                  Divider(
                      height: 24,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5)),
                  _LimitTile(
                    title: '복습 카드',
                    value: s.reviewLimit,
                    max: 1000,
                    step: 10,
                    onChanged: (v) => c.update(
                        SrsSettings(newLimit: s.newLimit, reviewLimit: v)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '매일 새로 시작하는 신규 카드와 복습 카드의 최대 개수예요.',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(text,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}

class _LimitTile extends StatelessWidget {
  final String title;
  final int value;
  final double max;
  final int step;
  final ValueChanged<int> onChanged;
  const _LimitTile(
      {required this.title,
      required this.value,
      required this.max,
      required this.onChanged,
      this.step = 1});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('$value장',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface)),
            ),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(0, max),
          min: 0,
          max: max,
          divisions: (max ~/ step),
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
