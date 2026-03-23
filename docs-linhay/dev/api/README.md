# API Docs

本目录用于接口定义与契约文档。

- `openapi.yaml`：对外 API 契约（如有 HTTP API）
- `schemas/`：共享数据结构定义（可选）

当前状态：Codex CLI / app-server 集成以本地进程与 JSON-RPC 为主，暂未引入 HTTP OpenAPI 契约。

当前可用文档：
- `docs-linhay/dev/api/codex-app-server-rpc.md`：Nolon 消费的 Codex app-server JSON-RPC 契约（方法/通知/错误语义）。
