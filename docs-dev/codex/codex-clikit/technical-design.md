# CodexCLIKit Technical Design

## Modules
- `CodexCLIKit/CLI`: full command models, help scanner, executor.
- `JsonRPCKit`: generic JSON-RPC 2.0 line transport/session/models.
- `CodexAppServerKit`: codex app-server protocol adapter (method registry + account APIs + runtime switching + notification waiters).
- `CodexCLIKit/Shared`: errors, shared models.

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
- Coverage details live in `docs-dev/codex/codex-clikit/cli-reference-coverage.md`.

## Error Layers
- Transport: process spawn / io.
- Protocol: malformed JSON-RPC / response mismatch.
- Domain: login/account level errors.
- Compatibility mode: runtime switch is primary, plus provider `auth.json` sync for standalone CLI usage.
