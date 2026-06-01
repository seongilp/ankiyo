// ankiyo LLM 프록시 — Vercel Node Serverless Function → Anthropic (직접)
//
// 클라이언트(Flutter)는 Anthropic 포맷으로 POST 한다.
// 이 함수가 ANTHROPIC_API_KEY(서버 환경변수)를 붙여 api.anthropic.com 으로
// forward. 키는 클라이언트에 절대 노출되지 않는다.
//
// 왜 Vercel인가: Anthropic은 Cloudflare IP를 차단하지만(CF Worker 불가),
// Vercel Serverless(미국 리전)는 통과한다.
//
// 경로: /api/messages  (vercel.json rewrite로 /v1/messages 도 허용)

const ANTHROPIC_URL = 'https://api.anthropic.com/v1/messages';
const DEFAULT_MODEL = 'claude-opus-4-8';

function setCors(res) {
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-methods', 'POST, OPTIONS');
  res.setHeader('access-control-allow-headers', 'content-type, anthropic-version');
  res.setHeader('access-control-max-age', '86400');
}

module.exports = async (req, res) => {
  setCors(res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'method not allowed' });

  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) return res.status(500).json({ error: 'ANTHROPIC_API_KEY missing' });

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch { return res.status(400).json({ error: 'invalid JSON' }); }
  }
  if (!body || typeof body !== 'object') body = {};

  // Anthropic Messages API payload.
  const payload = {
    model: body.model || DEFAULT_MODEL,
    max_tokens: body.max_tokens || 4096,
    messages: body.messages || [],
  };
  if (typeof body.system === 'string' && body.system.length) payload.system = body.system;
  if (typeof body.temperature === 'number') payload.temperature = body.temperature;

  let upstream;
  try {
    upstream = await fetch(ANTHROPIC_URL, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': key,
        'anthropic-version': req.headers['anthropic-version'] || '2023-06-01',
      },
      body: JSON.stringify(payload),
    });
  } catch (e) {
    return res.status(502).json({ error: `upstream error: ${e.message}` });
  }

  const text = await upstream.text();
  res.status(upstream.status);
  res.setHeader('content-type', 'application/json');
  return res.send(text);
};
