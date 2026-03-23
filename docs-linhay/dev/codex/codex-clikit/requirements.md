# CodexCLIKit Requirements

## Goals
- Build a standalone Codex CLI wrapper module under `libs/Providers`.
- Cover codex command-line options with typed APIs plus raw fallback.
- Provide full `codex app-server` JSON-RPC runtime support.
- Keep Nolon app layer orchestration-only.

## Constraints
- Use real `codex` binary for development and tests.
- No feature flag rollout; runtime path is default.
- Fixed codex version in CI.

## Non-goals
- No migration of `libs/CodexBar`.
- No fake CLI simulation binary.
