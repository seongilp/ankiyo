# DEPRECATED — Cloudflare Worker 사용 불가

`api.anthropic.com`이 Cloudflare 위에 호스팅돼 있어서 CF Worker가
Anthropic 호출하면 CF의 anti-abuse가 가로챔.

응답:
```json
{"error":{"type":"forbidden","message":"Request not allowed"}}
```

`type: "forbidden"`은 Anthropic 표준 에러 타입(`authentication_error`/`permission_error`/
`invalid_request_error`/...)에 없음. CF 자체가 답한 것.

**대체**: `../deno-proxy/` 사용. README 참고.

CF에 배포된 `ankiyo-proxy.zihado.workers.dev`는 dashboard에서 직접 삭제하거나
방치해도 무방 (비용 0).
