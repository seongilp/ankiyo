import 'package:flutter_test/flutter_test.dart';
import 'package:ankiyo/ui/format_due.dart';

void main() {
  final now = DateTime(2026, 5, 29, 10);

  test('과거/현재는 "지금"', () {
    expect(formatNextDue(now, now), '지금');
    expect(formatNextDue(now, now.subtract(const Duration(hours: 1))), '지금');
  });

  test('같은 날 저녁은 "오늘 저녁 7시"', () {
    final due = DateTime(2026, 5, 29, 19);
    expect(formatNextDue(now, due), '오늘 저녁 7시');
  });

  test('내일 오전은 "내일 오전 8시"', () {
    final due = DateTime(2026, 5, 30, 8);
    expect(formatNextDue(now, due), '내일 오전 8시');
  });

  test('며칠 뒤는 "N일 뒤"', () {
    expect(formatNextDue(now, DateTime(2026, 5, 31, 10)), '2일 뒤');
    expect(formatNextDue(now, DateTime(2026, 6, 3, 10)), '5일 뒤');
  });

  test('7~13일 뒤는 "다음 주"', () {
    expect(formatNextDue(now, DateTime(2026, 6, 5, 10)), '다음 주');
  });

  test('2주 이상은 "N주 뒤"', () {
    expect(formatNextDue(now, DateTime(2026, 6, 12, 10)), '2주 뒤');
  });
}
