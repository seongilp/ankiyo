import 'dart:convert';
import 'package:http/http.dart' as http;

class AnthropicException implements Exception {
  final String message;
  AnthropicException(this.message);
  @override
  String toString() => 'AnthropicException: $message';
}

class AnthropicClient {
  /// 비어 있으면 BYOK 모드로 간주 (게이트웨이가 자체 키로 호출).
  final String apiKey;
  final String model;

  /// 기본은 Anthropic 공식 엔드포인트. Cloudflare AI Gateway 쓰면
  /// 게이트웨이의 anthropic-native URL로 교체.
  /// 예: `https://gateway.ai.cloudflare.com/v1/{account}/{gateway}/anthropic`
  final String baseUrl;

  /// Cloudflare AI Gateway 의 cf-aig-authorization Bearer 토큰.
  /// 게이트웨이에 Authentication 켜져있을 때 필요.
  final String gatewayToken;

  final http.Client _http;

  AnthropicClient({
    this.apiKey = '',
    this.baseUrl = 'https://api.anthropic.com',
    this.gatewayToken = '',
    this.model = 'claude-haiku-4-5',
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  bool get _byok => apiKey.isEmpty;
  bool get _directToAnthropic => baseUrl == 'https://api.anthropic.com';

  Future<String> complete({
    required String system,
    required String user,
    int maxTokens = 8192,
  }) async {
    final headers = <String, String>{
      'content-type': 'application/json',
      'anthropic-version': '2023-06-01',
    };
    if (!_byok) {
      headers['x-api-key'] = apiKey;
    }
    if (_directToAnthropic && !_byok) {
      // 브라우저에서 Anthropic 직접 호출 시 필요. 게이트웨이 경유엔 불필요.
      headers['anthropic-dangerous-direct-browser-access'] = 'true';
    }
    if (gatewayToken.isNotEmpty) {
      headers['cf-aig-authorization'] = 'Bearer $gatewayToken';
    }

    final res = await _http.post(
      Uri.parse('$baseUrl/v1/messages'),
      headers: headers,
      body: jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user}
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
    if (first is! Map || first['type'] != 'text') {
      throw AnthropicException('예상치 못한 응답 형식');
    }
    return first['text'] as String;
  }
}
