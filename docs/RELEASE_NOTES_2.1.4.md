## nolon 2.1.4

### Changes
- Added the local Codex account-pool gateway with scheduler, sticky sessions, metrics, request logs, and failover/circuit-breaker controls so traffic can be routed through whichever account still has quota.
- Introduced the direct auto-switch mode that activates another account whenever the active quota window drops below the configured threshold, and writes detailed auto-switch events for diagnostics.
- Exposed the new controls to users via the App runtime view and the CLI (`nolon codex gateway start|stop|status|logs|doctor` plus `nolon codex autoswitch status|enable|disable|doctor`), including status summaries, active counts, sticky session counts, recent errors, and the latest auto-switch event log.
- Documented the feature design and operational runbook so the team can safely manage gateway/auto-switch deployments and failures.

### Downloads
| Platform | Architecture | Download |
|----------|--------------|----------|
| macOS | Apple Silicon (M1/M2/M3) | [nolon-arm64.dmg](https://github.com/linhay/nolon/releases/download/v2.1.4/nolon-arm64.dmg) |
| macOS | Intel | [nolon-x86_64.dmg](https://github.com/linhay/nolon/releases/download/v2.1.4/nolon-x86_64.dmg) |

### Installation
1. Download the appropriate DMG for your Mac
   - **Apple Silicon** (M1, M2, M3 chips): `nolon-arm64.dmg`
   - **Intel** (older Macs): `nolon-x86_64.dmg`
2. Open the DMG and drag nolon to Applications
3. Launch nolon from Applications

### System Requirements
- macOS 14.0 or later

---
*Built on 2026-03-13*
