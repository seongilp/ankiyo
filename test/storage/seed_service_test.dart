import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:ankiyo/storage/deck_repository.dart';
import 'package:ankiyo/storage/seed_service.dart';

class _FakeBundle extends CachingAssetBundle {
  final Map<String, String> files;
  _FakeBundle(this.files);

  @override
  Future<ByteData> load(String key) async {
    final s = files[key];
    if (s == null) throw FlutterError('asset not found: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(s)));
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final s = files[key];
    if (s == null) throw FlutterError('asset not found: $key');
    return s;
  }
}

Map<String, String> _bundleV(int version) => {
      'assets/decks/manifest.json': jsonEncode({
        'version': version,
        'files': ['deck01.json', 'deck02.json'],
      }),
      'assets/decks/deck01.json': jsonEncode({
        'name': 'Deck One',
        'cards': [
          {'front': '食べる', 'back': '먹다', 'isCloze': false},
          {'front': '飲む', 'back': '마시다', 'isCloze': false},
        ],
      }),
      'assets/decks/deck02.json': jsonEncode({
        'name': 'Deck Two',
        'cards': [
          {'front': 'あ', 'back': 'a', 'isCloze': false},
        ],
      }),
    };

void main() {
  final now = DateTime.utc(2026, 6, 7);

  test('첫 실행 시 manifest의 모든 덱을 시드한다', () async {
    final db = await databaseFactoryMemory.openDatabase('seed1.db');
    final repo = DeckRepository(db);
    final svc = SeedService(repo, db, bundle: _FakeBundle(_bundleV(1)));

    final count = await svc.seedIfNeeded(now);
    expect(count, 2);

    final decks = await repo.getDecks();
    expect(decks.map((d) => d.name).toSet(), {'Deck One', 'Deck Two'});

    final one = decks.firstWhere((d) => d.name == 'Deck One');
    final cards = await repo.getCards(one.id);
    expect(cards.length, 2);
    expect(cards.every((c) => c.state.reps == 0), true);
  });

  test('덱은 manifest 나열 순서대로 정렬된다', () async {
    final db = await databaseFactoryMemory.openDatabase('seed_order.db');
    final repo = DeckRepository(db);
    await SeedService(repo, db, bundle: _FakeBundle(_bundleV(1)))
        .seedIfNeeded(now);

    // getDecks 는 importedAt 오름차순 → manifest 의 files 순서와 같아야 한다.
    final names = (await repo.getDecks()).map((d) => d.name).toList();
    expect(names, ['Deck One', 'Deck Two']);
  });

  test('두 번째 실행은 같은 버전이면 다시 시드하지 않는다(중복 방지)', () async {
    final db = await databaseFactoryMemory.openDatabase('seed2.db');
    final repo = DeckRepository(db);
    final svc = SeedService(repo, db, bundle: _FakeBundle(_bundleV(1)));

    expect(await svc.seedIfNeeded(now), 2);
    expect(await svc.seedIfNeeded(now), 0);
    expect((await repo.getDecks()).length, 2);
  });

  test('버전이 올라가면 중복 없이 순서만 갱신하고 진행을 보존한다', () async {
    final db = await databaseFactoryMemory.openDatabase('seed3.db');
    final repo = DeckRepository(db);

    expect(
        await SeedService(repo, db, bundle: _FakeBundle(_bundleV(1)))
            .seedIfNeeded(now),
        2);

    // 사용자가 한 덱을 학습했다고 가정(진행 기록 생성)
    final one = (await repo.getDecks()).firstWhere((d) => d.name == 'Deck One');
    final card = (await repo.getCards(one.id)).first;
    await repo.updateCard(card.withState(card.state.copyWith(reps: 5)));

    // 버전 업 재시드: 새 덱 생성 0, 중복 없음
    expect(
        await SeedService(repo, db, bundle: _FakeBundle(_bundleV(2)))
            .seedIfNeeded(now),
        0);
    expect((await repo.getDecks()).length, 2);

    // 학습 진행 보존
    final after = (await repo.getCards(one.id)).firstWhere((c) => c.id == card.id);
    expect(after.state.reps, 5);
  });

  test('자산이 없으면 조용히 0을 반환한다', () async {
    final db = await databaseFactoryMemory.openDatabase('seed4.db');
    final repo = DeckRepository(db);
    final svc = SeedService(repo, db, bundle: _FakeBundle({}));
    expect(await svc.seedIfNeeded(now), 0);
    expect((await repo.getDecks()).isEmpty, true);
  });
}
