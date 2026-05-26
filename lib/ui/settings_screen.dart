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
          Text('하루 신규 카드 한도: ${s.newLimit}'),
          Slider(
            value: s.newLimit.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '${s.newLimit}',
            onChanged: (v) => c.update(
                SrsSettings(newLimit: v.round(), reviewLimit: s.reviewLimit)),
          ),
          const SizedBox(height: 24),
          Text('하루 복습 카드 한도: ${s.reviewLimit}'),
          Slider(
            value: s.reviewLimit.toDouble(),
            min: 0,
            max: 1000,
            divisions: 100,
            label: '${s.reviewLimit}',
            onChanged: (v) => c.update(
                SrsSettings(newLimit: s.newLimit, reviewLimit: v.round())),
          ),
        ],
      ),
    );
  }
}
