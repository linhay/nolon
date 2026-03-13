# Nolon 2.1.4

## Highlights
- Local Codex account-pool gateway with scheduling, sticky sessions, request logs, metrics, and failover/circuit-breaker controls so traffic is routed through healthy accounts.
- Direct auto-switch coordination that activates the next candidate whenever the active quota window drops below the configured threshold and logs rich diagnostics for each handoff.
- App runtime UI plus the new CLI doctor/status commands now surface gateway/auto-switch state, active counts, sticky sessions, recent errors, and the latest auto-switch event to match the operational runbook.
