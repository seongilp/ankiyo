// ankiyo LLM 프록시 — Vercel Node Serverless Function → OpenRouter
//
// 클라이언트(Flutter)는 OpenAI 호환 포맷으로 POST 한다(아래 경로).
// 이 함수가 OPENROUTER_API_KEY(서버 환경변수)를 붙여 OpenRouter로 forward.
// 키는 클라이언트에 절대 노출되지 않는다.
//
// 왜 Vercel인가: CF Worker/AI Gateway는 OpenRouter region 403이 나지만
// Vercel Serverless(일반 Node, 미국 리전)는 통과한다.
//
// 경로: /api/messages  (vercel.json rewrite로 /v1/chat/completions 도 허용)

const OPENROUTER_URL = 'https://openrouter.ai/api/v1/chat/completions';
const DEFAULT_MODEL = 'google/gemini-2.0-flash-001';

function setCors(res) {
  res.setHeader('access-control-allow-origin', '*');
  res.setHeader('access-control-allow-methods', 'POST, OPTIONS');
  res.setHeader('access-control-allow-headers', 'content-type, authorization');
  res.setHeader('access-control-max-age', '86400');
}

module.exports = async (req, res) => {
  setCors(res);
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'method not allowed' });

  const key = process.env.OPENROUTER_API_KEY;
  if (!key) return res.status(500).json({ error: 'OPENROUTER_API_KEY missing' });

  // body 파싱 (vercel은 보통 자동 파싱하지만 방어적으로 처리)
  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch { return res.status(400).json({ error: 'invalid JSON' }); }
  }
  if (!body || typeof body !== 'object') body = {};

  const payload = {
    model: body.model || DEFAULT_MODEL,
    messages: body.messages || [],
    max_tokens: body.max_tokens || 4096,
  };
  if (typeof body.temperature === 'number') payload.temperature = body.temperature;
  if (body.response_format) payload.response_format = body.response_format;

  let upstream;
  try {
    upstream = await fetch(OPENROUTER_URL, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${key}`,
        'HTTP-Referer': 'https://ankiyo.zihado.com',
        'X-Title': 'ankiyo',
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
