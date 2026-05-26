/// 웹 sqlite3(wasm)와 JSON 디코딩은 64비트 정수를 int·double·String·BigInt 등
/// 다양한 타입으로 반환할 수 있다. 어떤 타입이 와도 안전하게 int로 변환한다.
int asInt(Object? v) {
  if (v is int) return v;
  if (v is BigInt) return v.toInt();
  if (v is num) return v.toInt();
  if (v is String) return int.parse(v.trim());
  throw FormatException('정수로 변환할 수 없습니다: $v (${v.runtimeType})');
}
