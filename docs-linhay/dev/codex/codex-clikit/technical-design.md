# CodexCLIKit Technical Design

## Modules
- `CodexCLIKit/CLI`: full command models, help scanner, executor.
- `JsonRPCKit`: generic JSON-RPC 2.0 line transport/session/models.
- `CodexAppServerKit`: codex app-server protocol adapter (method registry + account APIs + runtime switching + notification waiters).
- `CodexCLIKit/Shared`: errors, shared models.
- `CodexProvider/CodexGeneratedFiles`: parser for codex-generated local files (`auth.json`, `sessions/*.jsonl` rollout lines), aligned with upstream `libs/codex` protocol/auth field names.

## Runtime Switch Flow
1. App selects account.
2. App reads token pair from account snapshot.
3. App calls `CodexRuntimeAccountSwitcher` in `CodexProvider`.
4. Switcher sends `account/login/start` with `chatgptAuthTokens`.
5. Switcher waits for `account/updated` notification before confirming success.
6. App syncs selected snapshot into provider `~/.codex/auth.json` (cleaned, without Nolon metadata) for CLI compatibility.
7. App records active account to `~/.nolon/codex/active-accounts.json` for runtime registry fallback.

## CLI Coverage
- Typed builders cover all top-level commands listed in current `codex --help`.
- Typed subcommand builders cover high-value command trees (`exec`, `login`, `mcp`, `app-server`, `sandbox`, `debug`, `cloud`, `features`).
- Coverage details live in `docs-linhay/dev/codex/codex-clikit/cli-reference-coverage.md`.

## Error Layers
- Transport: process spawn / io.
- Protocol: malformed JSON-RPC / response mismatch.
- Domain: login/account level errors.
- Compatibility mode: runtime switch is primary, plus provider `auth.json` sync for standalone CLI usage.

## Generated File Parsing
- `auth.json`: parse `auth_mode`, `OPENAI_API_KEY`, `tokens(id_token/access_token/refresh_token/account_id)`, `last_refresh`.
- `id_token` claims: decode JWT payload for `email`, `chatgpt_plan_type`, `chatgpt_user_id`, `chatgpt_account_id`.
- `history.jsonl`: parse JSONL entries (`session_id` + backward-compatible `conversation_id`, `ts`, `text`).
- `config.toml` and `managed_config.toml`: parse typed top-level fields and key nested blocks (`mcp_servers`, `features`, `history`, `sandbox_workspace_write`, `profiles`).
- `sessions/**/*.jsonl` and `archived_sessions/**/*.jsonl` rollout files: parse line envelope (`timestamp`, `type`, `payload`) and normalize:
  - `session_meta`
  - `response_item`
  - `compacted`
  - `turn_context`
  - `event_msg` (including `user_message`) and top-level `token_count`
- Cost usage scanner consumes normalized rollout parse result, no longer relies on ad-hoc dictionary field probing.
