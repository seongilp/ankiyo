import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:sembast/sembast.dart';
import 'package:uuid/uuid.dart';

import '../srs/card_state.dart';
import 'deck_repository.dart';
import 'models.dart';

/// 앱에 기본 내장된 "공부셋"을 첫 실행 시 한 번만 시드한다.
///
/// `assets/decks/manifest.json` 에 나열된 덱 JSON 파일들을 읽어 저장소에 넣는다.
/// 시드 완료 여부는 메타 스토어 플래그로 기록하므로, 사용자가 기본 덱을 지워도
/// 다시 생성되지 않는다. manifest 의 `version` 이 올라가면 새로 시드한다.
class SeedService {
  final DeckRepository _repo;
  final Database _db;
  final AssetBundle _bundle;
  final Uuid _uuid;

  static const _manifestPath = 'assets/decks/manifest.json';
  static const _metaStoreName = 'meta';
  static const _seedFlagKey = 'seedVersion';

  SeedService(
    this._repo,
    this._db, {
    AssetBundle? bundle,
    this._uuid = const Uuid(),
  }) : _bundle = bundle ?? rootBundle;

  StoreRef<String, Object?> get _meta =>
      stringMapStoreFactory.store(_metaStoreName).cast();

  /// 아직 시드하지 않았다면(또는 manifest 버전이 올라갔다면) 기본 덱을 시드한다.
  /// 반환값: 새로 시드한 덱 수(이미 최신이면 0).
  Future<int> seedIfNeeded(DateTime now) async {
    final manifestRaw = await _tryLoadString(_manifestPath);
    if (manifestRaw == null) return 0; // 내장 덱 자산이 없으면 조용히 건너뜀

    final manifest = _parseManifest(manifestRaw);
    if (manifest == null) return 0;

    final installed = await _installedVersion();
    if (installed >= manifest.version) return 0;

    // 정렬 키: manifest 나열 순서 = 화면 순서. 시드 시각과 무관하게 항상
    // 같은 순서가 되도록 고정 epoch + manifest 인덱스 오프셋을 쓴다.
    // (importedAt 은 UI에 표시되지 않고 정렬에만 쓰임.) 사용자가 직접 만든
    // 덱은 now() 기준이라 시드 덱들보다 뒤(아래)에 놓인다.
    final base = DateTime.utc(2020, 1, 1);

    // 이미 시드된 덱은 이름으로 찾아 순서만 갱신(학습 진행/카드 보존),
    // 없는 것만 새로 만든다 — 버전이 올라가도 중복 생성/진행 손실이 없다.
    final existingByName = {for (final d in await _repo.getDecks()) d.name: d};

    var created = 0;
    for (var i = 0; i < manifest.files.length; i++) {
      final raw = await _tryLoadString('assets/decks/${manifest.files[i]}');
      if (raw == null) continue;
      final parsed = _parseDeck(raw);
      if (parsed == null || parsed.cards.isEmpty) continue;

      final importedAt = base.add(Duration(minutes: i));
      final existing = existingByName[parsed.name];
      if (existing != null) {
        await _repo.updateDeckImportedAt(existing.id, importedAt);
      } else {
        await _saveSeedDeck(parsed, importedAt: importedAt, now: now);
        created++;
      }
    }

    await _setInstalledVersion(manifest.version);
    return created;
  }

  Future<void> _saveSeedDeck(
    _SeedDeck parsed, {
    required DateTime importedAt,
    required DateTime now,
  }) async {
    final deck = Deck(id: _uuid.v4(), name: parsed.name, importedAt: importedAt);
    final cards = parsed.cards
        .map((c) => StudyCard(
              id: _uuid.v4(),
              deckId: deck.id,
              frontHtml: c.front,
              backHtml: c.back,
              isCloze: c.isCloze,
              state: CardState.create(now),
            ))
        .toList();
    await _repo.saveDeck(deck, cards);
  }

  Future<int> _installedVersion() async {
    final v = await _meta.record(_seedFlagKey).get(_db);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  Future<void> _setInstalledVersion(int version) async {
    await _meta.record(_seedFlagKey).put(_db, version);
  }

  Future<String?> _tryLoadString(String path) async {
    try {
      return await _bundle.loadString(path);
    } catch (_) {
      return null;
    }
  }

  _Manifest? _parseManifest(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final version = (m['version'] as num?)?.toInt() ?? 1;
      final files = (m['files'] as List?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[];
      if (files.isEmpty) return null;
      return _Manifest(version: version, files: files);
    } catch (_) {
      return null;
    }
  }

  _SeedDeck? _parseDeck(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final name = (m['name'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;
      final cards = (m['cards'] as List?) ?? const [];
      final parsedCards = cards
          .whereType<Map>()
          .map((c) => _SeedCard(
                front: (c['front'] ?? '').toString().trim(),
                back: (c['back'] ?? '').toString().trim(),
                isCloze: c['isCloze'] == true,
              ))
          .where((c) => c.front.isNotEmpty && c.back.isNotEmpty)
          .toList(growable: false);
      return _SeedDeck(name: name, cards: parsedCards);
    } catch (_) {
      return null;
    }
  }
}

class _Manifest {
  final int version;
  final List<String> files;
  const _Manifest({required this.version, required this.files});
}

class _SeedDeck {
  final String name;
  final List<_SeedCard> cards;
  const _SeedDeck({required this.name, required this.cards});
}

class _SeedCard {
  final String front;
  final String back;
  final bool isCloze;
  const _SeedCard({
    required this.front,
    required this.back,
    required this.isCloze,
  });
}
