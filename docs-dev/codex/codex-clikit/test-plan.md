# CodexCLIKit Test Plan

## Provider Tests
- command rendering
- top-level and key subcommand help coverage against real codex
- app-server initialize/account read happy path
- app-server `account/updated` waiter behavior with mock server
- runtime account switch request shape + notification success gating validation
- generated files parser:
  - `auth.json` parse + JWT claim extraction (`chatgpt_plan_type`, account/user ids)
  - `history.jsonl` parse (`session_id` and backward-compatible `conversation_id`)
  - `config.toml` / `managed_config.toml` typed parse
  - rollout full item parse (`session_meta`, `response_item`, `compacted`, `turn_context`, `event_msg`, `token_count`)
  - `sessions/**/*.jsonl` + `archived_sessions/**/*.jsonl` file loading and parse
  - cost scanner token aggregation driven by normalized rollout parse output

## Nolon Tests
- orchestrator prefers runtime switch
- runtime activation updates active account registry (`active-accounts.json`)
- activation syncs selected snapshot to provider `auth.json` (cleaned JSON)
- CLI finalize flow syncs provider `auth.json` and marks active registry
- CLI login upsert path prefers selected account id when provided

## Execution Policy
- all tests use real `codex` binary
- tests skip with explicit reason when binary unavailable
- for Xcode tests in this repo, run with `DEPLOYMENT_LOCATION=NO` to avoid writing into system `Dev Builds` path
