import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/apkg/anki_model.dart';
import 'package:ankiyo/apkg/anki_note.dart';

void main() {
  test('AnkiModel.fromJson은 필드/템플릿/타입을 파싱한다', () {
    final json = {
      'id': 1,
      'name': 'Basic',
      'type': 0,
      'css': '.card{}',
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
    };
    final m = AnkiModel.fromJson(json);
    expect(m.id, 1);
    expect(m.type, 0);
    expect(m.fields.map((f) => f.name), ['Front', 'Back']);
    expect(m.templates.first.qfmt, '{{Front}}');
  });

  test('AnkiNote.fieldMap은 \\x1f로 분리해 필드명에 매핑한다', () {
    final m = AnkiModel.fromJson({
      'id': 1,
      'name': 'Basic',
      'type': 0,
      'css': '',
      'flds': [
        {'name': 'Front', 'ord': 0},
        {'name': 'Back', 'ord': 1},
      ],
      'tmpls': [],
    });
    final note = AnkiNote(id: 5, mid: 1, fieldsRaw: 'hello\x1fworld');
    final map = note.fieldMap(m);
    expect(map, {'Front': 'hello', 'Back': 'world'});
  });
}
