# ankiyo-proxy (Vercel → OpenRouter)

LLM 단어 추출용 프록시. 클라이언트(Flutter)는 OpenAI 호환 포맷으로
`POST /v1/chat/completions` 하고, Vercel Serverless Function이
`OPENROUTER_API_KEY`(서버 환경변수)를 붙여 OpenRouter로 forward한다.
키는 클라이언트에 노출되지 않는다.

## 왜 Vercel인가

- CF Worker / CF AI Gateway는 OpenRouter에서 "not available in your region"
  403이 난다(CF 엣지 IP). Vercel 일반 Node Serverless(미국 리전)는 통과.
- Anthropic 직접 호출은 CF가 막지만 여긴 OpenRouter 경유라 무관.

## 배포

```sh
cd vercel-proxy
npx vercel login          # 브라우저 OAuth (1회)
npx vercel link           # 프로젝트 연결 (또는 첫 deploy 시 생성)
# 환경변수 등록 (production)
npx vercel env add OPENROUTER_API_KEY production   # 값 붙여넣기
npx vercel --prod         # 배포
```

배포 URL 예: `https://ankiyo-proxy.vercel.app`

## 앱 연결

```sh
flutter build web --release --base-href /app/ \
  --dart-define=ANTHROPIC_BASE_URL=https://<프로젝트>.vercel.app
```

클라이언트(`anthropic_client.dart`)는 `$baseUrl/chat/completions`를 호출한다.
키는 클라이언트에 넣지 않는다(서버가 보유).

## 검증

```sh
curl https://<프로젝트>.vercel.app/health    # → ok

curl -X POST https://<프로젝트>.vercel.app/v1/chat/completions \
  -H 'content-type: application/json' \
  -d '{"model":"google/gemini-2.0-flash-001","max_tokens":50,"messages":[{"role":"user","content":"say 안녕"}]}'
```

## 모델 / 비용

- 기본 모델 `google/gemini-2.0-flash-001` (한국어 좋고 저렴, region 제한 없음).
  `api/messages.js`의 `DEFAULT_MODEL` 수정.
- OpenRouter 대시보드에서 크레딧 한도 설정 권장.
