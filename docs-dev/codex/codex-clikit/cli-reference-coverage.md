# Codex CLI Reference Coverage (Real Binary)

Updated: 2026-02-12
Source of truth: local `codex --help` and subcommand `--help` outputs.

## Top-level commands
- exec
- review
- login
- logout
- mcp
- mcp-server
- app-server
- app
- completion
- sandbox
- debug
- apply
- resume
- fork
- cloud
- features

## Subcommands covered by typed builders
- exec: `resume`, `review`
- login: `status`
- mcp: `list`, `get`, `add`, `remove`, `login`, `logout`
- app-server: `generate-ts`, `generate-json-schema`
- sandbox: `macos`, `linux`, `windows`
- debug: `app-server`, `app-server send-message-v2`
- cloud: `exec`, `status`, `list`, `apply`, `diff`
- features: `list`, `enable`, `disable`

## Notes
- `CodexGlobalOptions` holds shared global flags (`--model`, `--sandbox`, `--ask-for-approval`, `--search`, `--add-dir`, etc.).
- Command-specific option structs cover reference-only flags (for example `mcp add --env/--url`, `cloud list --limit/--cursor/--json`, `sandbox macos --log-denials`).
- Help coverage tests assert top-level and key subcommand sets against the real binary.
