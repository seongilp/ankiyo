// ankiyo Anthropic proxy — Cloudflare Workers
// 클라이언트 앱은 API 키 없이 이 worker URL을 baseUrl로 호출.
// Worker가 자신의 ANTHROPIC_API_KEY 시크릿으로 Anthropic에 요청을 forward.

const ANTHROPIC_BASE = 'https://api.anthropic.com';
const ALLOWED_PATHS = ['/v1/messages'];

export default {
  async fetch(req, env, ctx) {
    // CORS preflight
    if (req.method === 'OPTIONS') {
      return withCors(new Response(null, { status: 204 }));
    }

    const url = new URL(req.url);

    // 헬스체크
    if (url.pathname === '/' || url.pathname === '/health') {
      return withCors(new Response('ok', { status: 200 }));
    }

    if (!ALLOWED_PATHS.includes(url.pathname)) {
      return withCors(new Response('not found', { status: 404 }));
    }
    if (req.method !== 'POST') {
      return withCors(new Response('method not allowed', { status: 405 }));
    }
    if (!env.ANTHROPIC_API_KEY) {
      return withCors(
        new Response('server misconfigured: ANTHROPIC_API_KEY missing', {
          status: 500,
        }),
      );
    }

    // (선택) 간단한 분당 IP rate limit — Worker가 Rate Limiting binding을 가진 경우만 적용.
    // wrangler.toml 의 [[unsafe.bindings]] 로 등록한 경우 동작.
    if (env.RATE_LIMITER) {
      const ip = req.headers.get('cf-connecting-ip') || 'unknown';
      const { success } = await env.RATE_LIMITER.limit({ key: ip });
      if (!success) {
        return withCors(
          new Response('rate limit exceeded — try again later', {
            status: 429,
          }),
        );
      }
    }

    const body = await req.text();
    const upstreamReq = new Request(`${ANTHROPIC_BASE}${url.pathname}`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': env.ANTHROPIC_API_KEY,
        'anthropic-version':
          req.headers.get('anthropic-version') || '2023-06-01',
        'user-agent': 'ankiyo-proxy/0.1 (+cloudflare-workers)',
        'accept': 'application/json',
      },
      body,
    });

    let upstream;
    try {
      upstream = await fetch(upstreamReq);
    } catch (e) {
      return withCors(
        new Response(`upstream error: ${e.message}`, { status: 502 }),
      );
    }

    // DEBUG: 응답 일부 로깅
    const text = await upstream.text();
    console.log(
      'upstream status',
      upstream.status,
      'key_present',
      !!env.ANTHROPIC_API_KEY,
      'key_len',
      env.ANTHROPIC_API_KEY ? env.ANTHROPIC_API_KEY.length : 0,
      'body_preview',
      text.slice(0, 200),
    );

    const out = new Response(text, {
      status: upstream.status,
      headers: { 'content-type': 'application/json' },
    });
    return withCors(out);
  },
};

function withCors(res) {
  const r = new Response(res.body, res);
  r.headers.set('access-control-allow-origin', '*');
  r.headers.set('access-control-allow-methods', 'POST, OPTIONS');
  r.headers.set(
    'access-control-allow-headers',
    'content-type, anthropic-version',
  );
  r.headers.set('access-control-max-age', '86400');
  return r;
}
