/// 사용자 친화적인 다음 복습 시간 포매터.
/// 예) "오늘 저녁 7시", "내일 오전 8시", "3일 뒤", "다음 주"
String formatNextDue(DateTime now, DateTime due) {
  if (!due.isAfter(now)) return '지금';
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  final dayDiff = dueDay.difference(today).inDays;
  if (dayDiff == 0) return '오늘 ${_timeOfDay(due)}';
  if (dayDiff == 1) return '내일 ${_timeOfDay(due)}';
  if (dayDiff < 7) return '$dayDiff일 뒤';
  if (dayDiff < 14) return '다음 주';
  return '${(dayDiff / 7).round()}주 뒤';
}

String _timeOfDay(DateTime t) {
  final h = t.hour;
  if (h < 5) return '새벽 ${h == 0 ? 12 : h}시';
  if (h < 12) return '오전 $h시';
  if (h == 12) return '낮 12시';
  if (h < 18) return '오후 ${h - 12}시';
  if (h < 22) return '저녁 ${h - 12}시';
  return '밤 ${h - 12}시';
}
