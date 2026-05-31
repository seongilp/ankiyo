# ankiyo-proxy

Anthropic API 호출을 대리해주는 작은 Cloudflare Worker.
앱에는 키를 박지 않고 worker URL만 노출 → worker가 자기 환경변수 키로 Anthropic 호출.

## 배포 순서

1. **Cloudflare 계정** (없으면) — https://dash.cloudflare.com/sign-up. 무료.

2. **wrangler 설치 & 로그인**

   ```sh
   cd worker
   npm install
   npx wrangler login   # 브라우저 열려서 Cloudflare 로그인
   ```

3. **Anthropic 키를 Worker 시크릿으로 등록**

   ```sh
   npx wrangler secret put ANTHROPIC_API_KEY
   # 프롬프트 뜨면 sk-ant-... 키 붙여넣기
   ```

4. **배포**

   ```sh
   npx wrangler deploy
   ```

   끝나면 URL이 찍힘. 예: `https://ankiyo-proxy.<your-subdomain>.workers.dev`

5. **Flutter 앱에 baseUrl 주입해서 빌드**

   ```sh
   # .env 파일에 추가 (또는 직접 dart-define)
   echo "ANTHROPIC_BASE_URL=https://ankiyo-proxy.<your-subdomain>.workers.dev" >> /Users/zihado/work/ebs-claude/.env

   # 빌드 시 키는 빼고 base url만 주입 — worker가 키 갖고 있음
   flutter build apk --release \
     --dart-define=ANTHROPIC_BASE_URL=https://ankiyo-proxy.<your-subdomain>.workers.dev
   ```

   클라이언트엔 `ANTHROPIC_API_KEY` 안 박아도 됨. `AnthropicClient.apiKey`가 비면
   자동으로 프록시 모드 (브라우저-direct 헤더도 빠짐).

## 검증

배포 후 헬스체크:

```sh
curl https://ankiyo-proxy.<your-subdomain>.workers.dev/health
# → ok
```

샘플 호출:

```sh
curl -X POST https://ankiyo-proxy.<your-subdomain>.workers.dev/v1/messages \
  -H 'content-type: application/json' \
  -d '{
    "model": "claude-haiku-4-5",
    "max_tokens": 64,
    "messages": [{"role": "user", "content": "say hi in korean"}]
  }'
```

## Rate limiting (선택)

`wrangler.toml`의 `[[unsafe.bindings]]` 블록 주석 해제하고 다시 deploy 하면
IP당 분당 30회 제한 적용. Cloudflare Free 플랜에서 추가 비용 없음.

## 비용 통제

1. **Anthropic 대시보드 → Limits** 에서 월 사용량 한도 설정 (예: $10).
   초과 시 401 반환 → 앱이 알아서 에러 표시.
2. **Cloudflare Workers Free**: 하루 100k 요청 무료. 그 위는 $5/월 + $0.30 / 백만 요청.

## 로그 보기

```sh
npx wrangler tail
```
