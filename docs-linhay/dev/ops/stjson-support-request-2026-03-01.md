# STJSON 支持请求（2026-03-01）

## 提交状态
- 目标仓库：`https://github.com/linhay/STJSON`
- 检查结果：`has_issues=false`、`has_discussions=false`
- 结论：无法直接通过 GitHub Issue/Discussion 提交支持请求。

## 建议发送内容（可直接复制）

### Title
JSON-RPC response decode fails when producer omits `jsonrpc` field (compat request)

### Body
## Summary
`JSONRPC.Response` decoding appears to strictly require the `jsonrpc` field. In real `codex app-server` responses (codex-cli `0.101.0`), payloads can be returned as `{ "id": ..., "result": ... }` without `jsonrpc`, which causes decode failure (`keyNotFound("jsonrpc")`).

I’m requesting support for this compatibility case (or an opt-in compatibility decoding mode).

## Environment
- STJSON: `1.4.9` (via SwiftPM)
- Consumer project: `nolon` (`JsonRPCKit`)
- Runtime producer: `codex app-server` (version `codex-cli 0.101.0`)

## Actual producer output (captured)
Request:
```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"nolon-debug","version":"0.0.1"},"capabilities":{"experimentalApi":true}}}
{"jsonrpc":"2.0","method":"initialized","params":{}}
{"jsonrpc":"2.0","id":2,"method":"account/read","params":{"refreshToken":false}}
```

Response lines:
```json
{"id":1,"result":{"userAgent":"nolon-debug/0.101.0 (...)"}}
{"id":2,"result":{"account":{"type":"chatgpt","email":"***","planType":"team"},"requiresOpenaiAuth":true}}
```

## Current impact
When decoding as strict `JSONRPC.Response`, this fails with a missing-key error for `jsonrpc`.

## Expected behavior
One of the following would help:
1. Add a compatibility decoding API for response envelopes without `jsonrpc` (legacy/superset producers).
2. Add an optional decode strategy flag (strict vs compatible).
3. Provide a helper type in STJSON JSON-RPC module for loose response envelope normalization into `JSONRPC.Response`.

## Notes
- We still validate `id` matching and `result/error` exclusivity in our session layer.
- We only need compatibility for inbound response decoding; request/notification validation can remain strict.

Thanks — happy to provide a PR if you prefer a specific API shape.

## 本地复现命令（已验证）
```bash
python3 - <<'PY'
import json, subprocess
p = subprocess.Popen(['codex','app-server'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
for r in [
    {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"nolon-debug","version":"0.0.1"},"capabilities":{"experimentalApi":True}}},
    {"jsonrpc":"2.0","method":"initialized","params":{}},
    {"jsonrpc":"2.0","id":2,"method":"account/read","params":{"refreshToken":False}},
]:
    p.stdin.write(json.dumps(r)+'\n')
p.stdin.flush()
for _ in range(2):
    print(p.stdout.readline().strip())
p.terminate()
PY
```
