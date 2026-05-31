# ankiyo-proxy (Deno Deploy)

CF Worker는 Anthropic이 막아서 Deno Deploy로 옮긴 버전. **로컬 검증 완료.**

## 🌅 일어났을 때 — 3단계 (1분)

```sh
cd /Users/zihado/work/ankiyo/deno-proxy

# 1. OAuth 로그인 (브라우저 자동 열림, "Allow" 한 번 클릭)
deployctl login

# 2. 배포 (프로젝트 자동 생성)
deployctl deploy --project=ankiyo-proxy main.ts

# 3. 환경변수 등록 — 대시보드에서
#    https://dash.deno.com/projects/ankiyo-proxy → Settings → Environment Variables → Add
#    Key: ANTHROPIC_API_KEY
#    Value: (.env 에 있는 sk-ant-... 값)
```

배포 후 URL은 `https://ankiyo-proxy.deno.dev` 형식.

## 검증

```sh
curl https://ankiyo-proxy.deno.dev/health
# → ok

curl -X POST https://ankiyo-proxy.deno.dev/v1/messages \
  -H 'content-type: application/json' \
  -d '{"model":"claude-haiku-4-5","max_tokens":40,"messages":[{"role":"user","content":"hi"}]}'
# → {"content":[{"text":"Hello! ..."}], ...}
```

## 앱 빌드에 적용

```sh
# .env (또는 빌드 시 dart-define)
ANTHROPIC_BASE_URL=https://ankiyo-proxy.deno.dev

# 키는 더 이상 빌드에 박지 않아도 됨 (proxy mode 자동 동작)
flutter build apk --release \
  --dart-define=ANTHROPIC_BASE_URL=https://ankiyo-proxy.deno.dev
```

## 로컬 개발 (이미 검증됨)

```sh
ANTHROPIC_API_KEY=sk-ant-... deno run --allow-net --allow-env main.ts
# → Listening on http://localhost:8000
```

## 비용

- Deno Deploy Free: 1M req/month, 100k req/day. ankiyo 규모엔 차고 넘침.
- Anthropic 비용: 단어 추출 한 번에 ~1¢. 대시보드에서 월 한도 (예: $10/월) 잡아둘 것.

## 왜 CF Worker는 안 됨?

`api.anthropic.com`이 Cloudflare 위에 호스팅돼 있어서 CF Worker → 같은 CF 호스팅 서비스 호출이 CF 자체 anti-abuse로 차단됨. 응답 `type:"forbidden"`은 Anthropic 표준 에러 타입이 아닌 CF 가로채기의 흔적. Worker 무료/유료 무관, IP 풀 자체가 CF라 우회 불가. Deno Deploy는 AWS 기반 IP라 통과.
