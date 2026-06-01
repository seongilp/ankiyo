import 'dart:convert';
import 'package:http/http.dart' as http;

class AnthropicException implements Exception {
  final String message;
  AnthropicException(this.message);
  @override
  String toString() => 'AnthropicException: $message';
}

/// LLM 클라이언트 — Vercel 프록시(→ Anthropic 직접) 경유.
///
/// 클라이언트는 [baseUrl]/v1/messages 로 Anthropic 포맷 POST 한다. 키는
/// 클라이언트에 넣지 않는다(Vercel Serverless가 ANTHROPIC_API_KEY를 서버에서
/// 붙임). Anthropic은 Cloudflare IP를 차단하지만 Vercel(미국)은 통과.
class AnthropicClient {
  /// 사용 안 함(키는 서버에). 시그니처 호환용.
  final String apiKey;

  /// 프록시 베이스 URL. 예: https://ankiyo-proxy.vercel.app
  /// 비어 있으면 LLM 미설정으로 간주.
  final String baseUrl;

  /// Anthropic 모델명.
  final String model;

  /// 사용 안 함(과거 CF AI Gateway 잔재). 시그니처 호환용.
  final String gatewayToken;

  final http.Client _http;

  AnthropicClient({
    this.apiKey = '',
    this.baseUrl = '',
    this.gatewayToken = '',
    this.model = 'claude-opus-4-8',
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
      'anthropic-version': '2023-06-01',
    };

    final res = await _http.post(
      Uri.parse('$baseUrl/v1/messages'),
      headers: headers,
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      }),
    );
    if (res.statusCode != 200) {
      throw AnthropicException('HTTP ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, Object?>;
    final content = body['content'];
    if (content is! List || content.isEmpty) {
      throw AnthropicException('빈 응답');
    }
    final first = content.first;
    if (first is! Map || first['type'] != 'text' || first['text'] is! String) {
      throw AnthropicException('예상치 못한 응답 형식');
    }
    return first['text'] as String;
  }
}
