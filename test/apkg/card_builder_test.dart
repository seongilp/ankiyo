import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/apkg/anki_model.dart';
import 'package:ankiyo/apkg/anki_note.dart';
import 'package:ankiyo/apkg/card_builder.dart';

void main() {
  final builder = const CardBuilder();

  group('표준 노트', () {
    final basic = AnkiModel.fromJson({
      'id': 1,
      'name': 'Basic',
      'type': 0,
      'css': '',
      'flds': [
        {'name': 'Front', 'ord': 0},
        {'name': 'Back', 'ord': 1},
      ],
      'tmpls': [
        {
          'name': 'Card 1',
          'ord': 0,
          'qfmt': '{{Front}}',
          'afmt': '{{FrontSide}}<hr>{{Back}}'
        },
      ],
    });

    test('필드 치환과 FrontSide를 처리한다', () {
      final note = AnkiNote(id: 1, mid: 1, fieldsRaw: '안녕\x1fhello');
      final card = builder.build(note: note, model: basic, ord: 0);
      expect(card.frontHtml, '안녕');
      expect(card.backHtml, '안녕<hr>hello');
      expect(card.isCloze, false);
    });

    test('조건부 섹션을 처리한다 (#있을때 / ^없을때)', () {
      final model = AnkiModel.fromJson({
        'id': 2,
        'name': 'C',
        'type': 0,
        'css': '',
        'flds': [
          {'name': 'Front', 'ord': 0},
          {'name': 'Hint', 'ord': 1},
        ],
        'tmpls': [
          {
            'name': 'Card 1',
            'ord': 0,
            'qfmt': '{{Front}}{{#Hint}} ({{Hint}}){{/Hint}}',
            'afmt': ''
          },
        ],
      });
      final withHint = builder.build(
          note: AnkiNote(id: 1, mid: 2, fieldsRaw: 'Q\x1f힌트'),
          model: model,
          ord: 0);
      expect(withHint.frontHtml, 'Q (힌트)');
      final noHint = builder.build(
          note: AnkiNote(id: 2, mid: 2, fieldsRaw: 'Q\x1f'),
          model: model,
          ord: 0);
      expect(noHint.frontHtml, 'Q');
    });
  });

  group('cloze 노트', () {
    final cloze = AnkiModel.fromJson({
      'id': 10,
      'name': 'Cloze',
      'type': 1,
      'css': '',
      'flds': [
        {'name': 'Text', 'ord': 0},
        {'name': 'Extra', 'ord': 1},
      ],
      'tmpls': [
        {
          'name': 'Cloze',
          'ord': 0,
          'qfmt': '{{cloze:Text}}',
          'afmt': '{{cloze:Text}}<br>{{Extra}}'
        },
      ],
    });

    test('앞면은 활성 클로즈를 가리고 다른 클로즈는 노출한다', () {
      final note = AnkiNote(
          id: 1,
          mid: 10,
          fieldsRaw: '{{c1::파리}}는 {{c2::프랑스}}의 수도\x1f메모');
      final card1 = builder.build(note: note, model: cloze, ord: 0); // c1
      expect(card1.frontHtml, '[...]는 프랑스의 수도');
      expect(card1.backHtml, contains('파리'));
      expect(card1.backHtml, contains('class="cloze"'));
      expect(card1.isCloze, true);
    });

    test('힌트가 있으면 [힌트] 형태로 가린다', () {
      final note =
          AnkiNote(id: 2, mid: 10, fieldsRaw: '정답은 {{c1::42::숫자}}\x1f');
      final card = builder.build(note: note, model: cloze, ord: 0);
      expect(card.frontHtml, '정답은 [숫자]');
    });

    test('clozeNumbers는 노트의 distinct 클로즈 번호를 반환한다', () {
      final note = AnkiNote(
          id: 3, mid: 10, fieldsRaw: '{{c1::a}} {{c2::b}} {{c1::c}}\x1f');
      expect(builder.clozeNumbers(note, cloze), [1, 2]);
    });
  });
}
