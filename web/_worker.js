// Cloudflare Pages advanced-mode worker.
//
// 목적: *.pages.dev 기본 도메인은 Cloudflare Access로 직접 보호할 수 없다.
// 그래서 pages.dev로 들어온 트래픽을 Access 게이트가 걸린 커스텀 도메인
// (ankiyo.zihado.com)으로 302 리다이렉트시켜, 자산 노출 전에 로그인으로 보낸다.
//
// 주의: _worker.js(advanced mode)가 있으면 _redirects/_headers 는 무시되므로
// SPA fallback(딥링크 새로고침 시 index.html)을 여기서 직접 처리한다.

const GATED_HOST = 'ankiyo.zihado.com';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // pages.dev 기본 도메인 → Access 걸린 커스텀 도메인으로 강제 이동.
    if (url.hostname.endsWith('.pages.dev')) {
      url.hostname = GATED_HOST;
      url.protocol = 'https:';
      return Response.redirect(url.toString(), 302);
    }

    // 커스텀 도메인: 정적 자산 서빙.
    const res = await env.ASSETS.fetch(request);

    // 알 수 없는 경로는 index.html로 폴백 (Flutter 클라이언트 라우팅).
    if (res.status === 404) {
      const idx = new URL(request.url);
      idx.pathname = '/';
      idx.search = '';
      return env.ASSETS.fetch(new Request(idx.toString(), request));
    }

    return res;
  },
};
