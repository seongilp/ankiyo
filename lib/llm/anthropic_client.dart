import 'dart:convert';
import 'package:http/http.dart' as http;

class AnthropicException implements Exception {
  final String message;
  AnthropicException(this.message);
  @override
  String toString() => 'AnthropicException: $message';
}

/// LLM 클라이언트 — Vercel 프록시(→ OpenRouter) 경유.
///
/// 클라이언트는 [baseUrl]/chat/completions 로 POST 한다. 키는 클라이언트에
/// 넣지 않는다(Vercel Serverless가 OPENROUTER_API_KEY를 서버에서 붙임).
/// CF Worker/AI Gateway는 OpenRouter region 403이 나지만 Vercel(미국)은 통과.
///
/// [apiKey]는 비워 두는 게 정상(프록시 모드). 값이 있으면 직접 호출 모드로
/// authorization 헤더를 붙인다(로컬 테스트용).
///
/// 클래스명은 호환을 위해 유지(앱 배선 변경 최소화).
class AnthropicClient {
  /// (선택) OpenRouter 키 직접 호출 모드. 프록시 경유 시 빈 값.
  final String apiKey;

  /// 프록시 베이스 URL. 예: https://ankiyo-proxy.vercel.app
  /// 비어 있으면 LLM 미설정으로 간주.
  final String baseUrl;

  /// OpenRouter 모델 슬러그. Claude는 일부 region에서 막혀 Gemini Flash 기본.
  final String model;

  /// 사용 안 함(과거 CF AI Gateway 잔재). 시그니처 호환용.
  final String gatewayToken;

  final http.Client _http;

  AnthropicClient({
    this.apiKey = '',
    this.baseUrl = '',
    this.gatewayToken = '',
    this.model = 'google/gemini-2.0-flash-001',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// 프록시 URL이 설정돼 있으면 사용 가능.
  bool get isConfigured => baseUrl.isNotEmpty;

  Future<String> complete({
    required String system,
    required String user,
    int maxTokens = 8192,
  }) async {
    if (baseUrl.isEmpty) {
      throw AnthropicException('LLM 프록시가 설정되지 않았어요.');
    }
    final headers = <String, String>{
      'content-type': 'application/json',
      // 프록시 모드에선 키 불필요. 직접 호출 모드(로컬)일 때만 붙임.
      if (apiKey.isNotEmpty) 'authorization': 'Bearer $apiKey',
    };

    final res = await _http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: headers,
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      }),
    );
    if (res.statusCode != 200) {
      throw AnthropicException('HTTP ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, Object?>;
    final choices = body['choices'];
    if (choices is! List || choices.isEmpty) {
      throw AnthropicException('빈 응답');
    }
    final first = choices.first;
    if (first is! Map) {
      throw AnthropicException('예상치 못한 응답 형식');
    }
    final message = first['message'];
    if (message is! Map || message['content'] is! String) {
      throw AnthropicException('예상치 못한 응답 형식');
    }
    return message['content'] as String;
  }
}
