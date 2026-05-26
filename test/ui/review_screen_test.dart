import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ankiyo/srs/card_state.dart';
import 'package:ankiyo/srs/scheduler.dart';
import 'package:ankiyo/storage/deck_repository.dart';
import 'package:ankiyo/storage/models.dart';
import 'package:ankiyo/ui/controllers/review_controller.dart';
import 'package:ankiyo/ui/review_screen.dart';

void main() {
  testWidgets('앞면 → 정답 보기 → 평가 흐름', (tester) async {
    final now = DateTime.utc(2026, 1, 1, 9);

    // sembast는 실제 비동기라 runAsync로 구동한다. 로딩 스피너가 무한 애니메이션이라
    // pumpAndSettle 대신 pump + 짧은 실제 지연으로 단계별 렌더링한다.
    await tester.runAsync(() async {
      final db = await databaseFactoryMemory.openDatabase('w.db');
      final repo = DeckRepository(db);
      await repo.saveDeck(Deck(id: 'd1', name: 'D', importedAt: now), [
        StudyCard(
            id: 'c1',
            deckId: 'd1',
            frontHtml: '<b>앞</b>',
            backHtml: '뒤',
            isCloze: false,
            state: CardState.create(now)),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => ReviewController(
              repo: repo,
              scheduler: const Scheduler(),
              deckId: 'd1',
              newLimit: 20,
              reviewLimit: 200,
              clock: () => now),
          child: const ReviewScreen(),
        ),
      ));

      // load() 완료 대기 후 프레임 갱신
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('정답 보기  ·  Space'), findsOneWidget);
      await tester.tap(find.text('정답 보기  ·  Space'));
      await tester.pump();

      expect(find.text('좋음'), findsOneWidget);
      await tester.tap(find.text('좋음'));
      // rate()의 비동기 저장 완료 대기
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('오늘 학습 완료!'), findsOneWidget);
    });
  });
}
