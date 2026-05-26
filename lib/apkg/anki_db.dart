import 'dart:convert';
import 'package:sqlite3/common.dart';
import 'anki_model.dart';
import 'anki_note.dart';
import 'card_builder.dart';
import 'num_parse.dart';

class ParsedDeck {
  final int ankiId;
  final String name;
  const ParsedDeck({required this.ankiId, required this.name});
}

class ParsedCard {
  final int deckAnkiId;
  final String frontHtml;
  final String backHtml;
  final bool isCloze;
  const ParsedCard({
    required this.deckAnkiId,
    required this.frontHtml,
    required this.backHtml,
    required this.isCloze,
  });
}

/// 이미 열린 sqlite [CommonDatabase]에서 Anki 컬렉션을 읽는다.
/// (DB 오픈은 플랫폼별 호출자가 담당 — 웹: wasm, 네이티브: 파일)
class AnkiCollectionReader {
  final CommonDatabase db;
  final CardBuilder _builder;

  AnkiCollectionReader(this.db, {this._builder = const CardBuilder()});

  Map<String, dynamic> _col() {
    final row = db.select('SELECT models, decks FROM col LIMIT 1').first;
    return {
      'models': jsonDecode(row['models'] as String) as Map<String, dynamic>,
      'decks': jsonDecode(row['decks'] as String) as Map<String, dynamic>,
    };
  }

  List<ParsedDeck> readDecks() {
    final decks = _col()['decks'] as Map<String, dynamic>;
    return decks.entries.map((e) {
      final v = Map<String, dynamic>.from(e.value as Map);
      return ParsedDeck(
          ankiId: asInt(e.key), name: v['name'] as String? ?? '?');
    }).toList();
  }

  List<ParsedCard> readCards() {
    final col = _col();
    final modelsJson = col['models'] as Map<String, dynamic>;
    final models = <int, AnkiModel>{};
    for (final entry in modelsJson.entries) {
      final m = AnkiModel.fromJson(Map<String, dynamic>.from(entry.value as Map));
      models[m.id] = m;
    }

    // 노트 캐시
    final notes = <int, AnkiNote>{};
    for (final r in db.select('SELECT id, mid, flds FROM notes')) {
      final id = asInt(r['id']);
      notes[id] = AnkiNote(
        id: id,
        mid: asInt(r['mid']),
        fieldsRaw: r['flds'] as String,
      );
    }

    final result = <ParsedCard>[];
    for (final r in db.select('SELECT nid, did, ord FROM cards')) {
      final note = notes[asInt(r['nid'])];
      if (note == null) continue;
      final model = models[note.mid];
      if (model == null) continue; // 깨진 노트 → 건너뜀
      try {
        final built =
            _builder.build(note: note, model: model, ord: asInt(r['ord']));
        result.add(ParsedCard(
          deckAnkiId: asInt(r['did']),
          frontHtml: built.frontHtml,
          backHtml: built.backHtml,
          isCloze: built.isCloze,
        ));
      } catch (_) {
        // 렌더 실패 카드는 건너뛰고 계속
        continue;
      }
    }
    return result;
  }
}
