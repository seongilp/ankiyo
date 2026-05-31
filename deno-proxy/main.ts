// ankiyo Anthropic proxy — Deno Deploy
// Anthropic이 Cloudflare Workers IP를 차단해서 Deno Deploy로 이주.

const ANTHROPIC_BASE = "https://api.anthropic.com";
const ALLOWED_PATHS = new Set(["/v1/messages"]);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return withCors(new Response(null, { status: 204 }));

  const url = new URL(req.url);

  if (url.pathname === "/" || url.pathname === "/health") {
    return withCors(new Response("ok", { status: 200 }));
  }

  if (!ALLOWED_PATHS.has(url.pathname)) {
    return withCors(new Response("not found", { status: 404 }));
  }
  if (req.method !== "POST") {
    return withCors(new Response("method not allowed", { status: 405 }));
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return withCors(
      new Response("server misconfigured: ANTHROPIC_API_KEY missing", { status: 500 }),
    );
  }

  const body = await req.text();
  let upstream: Response;
  try {
    upstream = await fetch(`${ANTHROPIC_BASE}${url.pathname}`, {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": apiKey,
        "anthropic-version": req.headers.get("anthropic-version") ?? "2023-06-01",
        "accept": "application/json",
        "user-agent": "ankiyo-proxy/0.1 (+deno-deploy)",
      },
      body,
    });
  } catch (e) {
    return withCors(new Response(`upstream error: ${(e as Error).message}`, { status: 502 }));
  }

  // 응답을 다시 감싸서 CORS 추가
  const text = await upstream.text();
  return withCors(
    new Response(text, {
      status: upstream.status,
      headers: { "content-type": "application/json" },
    }),
  );
});

function withCors(res: Response): Response {
  const r = new Response(res.body, res);
  r.headers.set("access-control-allow-origin", "*");
  r.headers.set("access-control-allow-methods", "POST, OPTIONS");
  r.headers.set("access-control-allow-headers", "content-type, anthropic-version");
  r.headers.set("access-control-max-age", "86400");
  return r;
}
