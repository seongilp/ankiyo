#!/usr/bin/env bash
# ankiyo 웹앱(/app/) → Cloudflare Pages(project: ankiyo) 배포.
#
# 구조: 배포 루트 / = 랜딩(web/landing.html), /app/ = Flutter 빌드.
# 서비스워커는 끈다(--pwa-strategy=none) + 기존에 등록된 옛 SW를 죽이는
# kill-switch SW 를 함께 올려 stale 캐시 문제를 근본적으로 없앤다.
#
# 사용: scripts/deploy_web.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

PROXY_URL="${ANKIYO_PROXY_URL:-https://ankiyo-proxy.vercel.app}"
PROJECT="${ANKIYO_PAGES_PROJECT:-ankiyo}"

echo "[1/4] flutter build web (base-href /app/, SW off, proxy=$PROXY_URL)"
flutter build web --release --base-href /app/ --pwa-strategy=none \
  --dart-define=ANTHROPIC_BASE_URL="$PROXY_URL"

echo "[2/4] stage deploy dir (landing + app)"
rm -rf build/deploy
mkdir -p build/deploy
cp web/landing.html build/deploy/index.html
cp -r build/web build/deploy/app

echo "[3/4] inject kill-switch service worker (cleans up old registrations)"
# 옛 SW 가 업데이트 체크로 이 파일을 받으면, 캐시를 모두 지우고 자신을
# unregister 한 뒤 열린 탭을 새로고침한다. 새 빌드는 SW 를 등록하지 않으므로
# 이후로는 항상 최신이 뜬다.
cat > build/deploy/app/flutter_service_worker.js <<'SW'
// kill-switch: 과거 Flutter 서비스워커 제거용. 등록하지 않는다.
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    try {
      const keys = await caches.keys();
      await Promise.all(keys.map(function (k) { return caches.delete(k); }));
      await self.registration.unregister();
      const clients = await self.clients.matchAll({ type: 'window' });
      clients.forEach(function (c) { c.navigate(c.url); });
    } catch (e) { /* noop */ }
  })());
});
SW

echo "[4/4] wrangler pages deploy → project '$PROJECT'"
npx wrangler pages deploy build/deploy \
  --project-name "$PROJECT" --branch main --commit-dirty=true

echo "✅ done"
