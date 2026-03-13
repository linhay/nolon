## nolon 2.1.5

### Changes
- Added the local Codex account-pool gateway with scheduling, sticky sessions, metrics, request logs, and failover/circuit-breaker controls so traffic is routed through healthy accounts.
- Introduced the direct auto-switch mode that activates the next candidate whenever the active quota window drops below the configured threshold and logs rich diagnostics for each handoff.
- Exposed the gateway and auto-switch controls through both the App runtime view and the CLI (`nolon codex gateway start|stop|status|logs|doctor` plus `nolon codex autoswitch status|enable|disable|doctor`), showing status summaries, active counts, sticky sessions, recent errors, and the latest auto-switch events.
- Documented the feature design and operational runbook so the team can confidently operate or troubleshoot the new pathways.
