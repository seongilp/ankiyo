// ankiyo proxy — Cloudflare Worker → OpenRouter
//
// 클라이언트(Flutter)는 기존 Anthropic 포맷 그대로 POST /v1/messages 한다.
// 이 Worker가 OpenRouter(OpenAI 호환)로 번역해 호출하고, 응답을 다시
// Anthropic 포맷으로 되돌려준다. → 클라이언트 코드 변경 최소화.
//
// 왜 OpenRouter인가: Anthropic이 Cloudflare IP를 차단하지만, OpenRouter는
// CF를 막지 않으므로 Worker에서 그대로 호출된다. 키는 Worker secret에만 존재.

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';

// 클라이언트가 보내는 Anthropic 모델명 → OpenRouter 모델 슬러그 매핑.
// 알 수 없는 값은 그대로 통과(이미 슬러그 형태면 그대로 사용).
//
// 주의: Anthropic Claude 모델은 이 Worker가 도는 CF 엣지 지역에서
// "not available in your region" 403이 난다. 한국어 품질 좋고 지역 제한
// 없는 google/gemini-2.0-flash-001 로 매핑한다 (빠르고 저렴).
const DEFAULT_MODEL = 'google/gemini-2.0-flash-001';
const MODEL_MAP = {
  'claude-haiku-4-5': DEFAULT_MODEL,
  'claude-3-5-haiku': DEFAULT_MODEL,
  'claude-sonnet-4-5': 'google/gemini-2.0-flash-001',
  'claude-3-5-sonnet': 'google/gemini-2.0-flash-001',
};

export default {
  async fetch(req, env) {
    if (req.method === 'OPTIONS') return withCors(new Response(null, { status: 204 }));

    const url = new URL(req.url);
    if (url.pathname === '/' || url.pathname === '/health') {
      return withCors(new Response('ok', { status: 200 }));
    }
    if (url.pathname !== '/v1/messages') {
      return withCors(new Response('not found', { status: 404 }));
    }
    if (req.method !== 'POST') {
      return withCors(new Response('method not allowed', { status: 405 }));
    }
    if (!env.OPENROUTER_API_KEY) {
      return withCors(new Response('server misconfigured: OPENROUTER_API_KEY missing', { status: 500 }));
    }

    // (선택) IP rate limit
    if (env.RATE_LIMITER) {
      const ip = req.headers.get('cf-connecting-ip') || 'unknown';
      const { success } = await env.RATE_LIMITER.limit({ key: ip });
      if (!success) {
        return withCors(new Response('rate limit exceeded — try again later', { status: 429 }));
      }
    }

    let body;
    try {
      body = await req.json();
    } catch {
      return withCors(new Response('invalid JSON', { status: 400 }));
    }

    // Anthropic 포맷 → OpenAI(OpenRouter) 포맷.
    const messages = [];
    if (typeof body.system === 'string' && body.system.length) {
      messages.push({ role: 'system', content: body.system });
    }
    for (const m of body.messages || []) {
      // Anthropic content는 문자열 또는 [{type:'text',text}] 배열.
      let content = m.content;
      if (Array.isArray(content)) {
        content = content.map((p) => (typeof p === 'string' ? p : p.text || '')).join('');
      }
      messages.push({ role: m.role, content });
    }

    const model = MODEL_MAP[body.model] || body.model || DEFAULT_MODEL;
    const orPayload = {
      model,
      messages,
      max_tokens: body.max_tokens || 4096,
    };

    let upstream;
    try {
      upstream = await fetch(OPENROUTER_URL, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${env.OPENROUTER_API_KEY}`,
          // OpenRouter 권장 헤더 (랭킹/식별용, 선택).
          'HTTP-Referer': 'https://ankiyo.zihado.com',
          'X-Title': 'ankiyo',
        },
        body: JSON.stringify(orPayload),
      });
    } catch (e) {
      return withCors(new Response(`upstream error: ${e.message}`, { status: 502 }));
    }

    const text = await upstream.text();
    if (!upstream.ok) {
      // 에러는 그대로 전달 (디버깅 편의).
      return withCors(new Response(text, { status: upstream.status, headers: { 'content-type': 'application/json' } }));
    }

    // OpenAI 포맷 응답 → Anthropic 포맷으로 되돌리기.
    let out;
    try {
      const data = JSON.parse(text);
      const reply = data.choices?.[0]?.message?.content ?? '';
      out = {
        content: [{ type: 'text', text: reply }],
        model: data.model || model,
        usage: data.usage || null,
      };
    } catch (e) {
      return withCors(new Response(`bad upstream response: ${e.message}`, { status: 502 }));
    }

    return withCors(new Response(JSON.stringify(out), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    }));
  },
};

function withCors(res) {
  const r = new Response(res.body, res);
  r.headers.set('access-control-allow-origin', '*');
  r.headers.set('access-control-allow-methods', 'POST, OPTIONS');
  r.headers.set('access-control-allow-headers', 'content-type, anthropic-version');
  r.headers.set('access-control-max-age', '86400');
  return r;
}
