import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/apkg/anki_model.dart';
import 'package:ankiyo/apkg/num_parse.dart';

void main() {
  test('asInt는 int/double/String/BigInt를 모두 int로 변환한다', () {
    expect(asInt(42), 42);
    expect(asInt(42.0), 42);
    // 웹 sqlite3/JSON이 큰 정수를 String으로 줄 때 (실제 버그 케이스)
    expect(asInt('1991230002'), 1991230002);
    expect(asInt(' 100 '), 100);
    expect(asInt(BigInt.from(1607000000000)), 1607000000000);
  });

  test('변환 불가 값은 예외', () {
    expect(() => asInt(null), throwsA(isA<FormatException>()));
    expect(() => asInt('abc'), throwsA(isA<FormatException>()));
  });

  test('AnkiModel.fromJson은 id/ord/type이 String이어도 파싱한다 (웹 케이스)', () {
    final m = AnkiModel.fromJson({
      'id': '1607000000000', // 웹에서 String으로 올 수 있음
      'name': 'Basic',
      'type': '0',
      'css': '',
      'flds': [
        {'name': 'Front', 'ord': '0'},
        {'name': 'Back', 'ord': '1'},
      ],
      'tmpls': [
        {'name': 'Card 1', 'ord': '0', 'qfmt': '{{Front}}', 'afmt': '{{Back}}'},
      ],
    });
    expect(m.id, 1607000000000);
    expect(m.type, 0);
    expect(m.fields.map((f) => f.name), ['Front', 'Back']);
  });
}
