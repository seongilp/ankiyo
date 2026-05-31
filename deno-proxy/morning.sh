#!/usr/bin/env bash
# 일어났을 때 한 번에 돌리는 스크립트.
# OAuth만 너가 해주면 나머지는 자동.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
export PATH="$HOME/.deno/bin:$PATH"

echo "🌅 ankiyo deno-proxy 배포"
echo ""

echo "[1/3] Deno Deploy 로그인 — 브라우저 열리면 Allow 누르기"
deployctl login
echo ""

echo "[2/3] 프로젝트 생성 + 코드 배포"
deployctl deploy --project=ankiyo-proxy main.ts
echo ""

echo "[3/3] 환경변수 등록 안내"
KEY=$(grep "^ANTHROPIC_API_KEY=" /Users/zihado/work/ebs-claude/.env | cut -d= -f2- | tr -d '\n\r ')
cat <<EOF
   대시보드 열기: https://dash.deno.com/projects/ankiyo-proxy/settings
   Environment Variables → Add Variable:
     Name:  ANTHROPIC_API_KEY
     Value: $KEY
   저장 후 자동 재배포됨.

검증 (env var 등록 후):
   curl -X POST https://ankiyo-proxy.deno.dev/v1/messages \\
     -H 'content-type: application/json' \\
     -d '{"model":"claude-haiku-4-5","max_tokens":40,"messages":[{"role":"user","content":"hi"}]}'

앱 빌드에 적용:
   echo 'ANTHROPIC_BASE_URL=https://ankiyo-proxy.deno.dev' >> /Users/zihado/work/ebs-claude/.env
EOF
