# Nolon

English | [中文](README_ZH.md)

Nolon is a macOS workspace orchestrator for AI coding tools. It keeps Skills / Workflows / MCP in one canonical source at `~/.nolon/skills`, then projects them into Codex, Claude Code, Cursor, and 25+ providers with provider-specific behavior.

## Why Nolon

- Maintain once, reuse everywhere: one resource set across multiple providers.
- Reduce configuration drift: centralized link/install checks and repair flows.
- Lower context-switch cost: one workspace for provider-specific capabilities.

## Core Capabilities

- Unified provider management for 25+ AI coding assistants.
- Single source of truth at `~/.nolon/skills`.
- Resource Center for remote discovery and install from [Clawdhub](https://clawdhub.com).
- MCP configuration and installation management per provider.
- Codex-focused surfaces: Rules / Agents / Binary / Advanced / Usage.
- Migration and repair for unmanaged resources and broken links.

## Download

- Latest release: https://github.com/linhay/nolon/releases/latest
- Sparkle appcast: https://linhay.github.io/nolon/appcast.xml
- Project site: https://linhay.github.io/nolon/

## 5-Minute Quick Start

1. Download and install Nolon from the latest release.
2. Launch the app and select a provider (for example, Codex).
3. Open Resource Center and install one Skill or MCP.
4. Return to provider tabs and confirm the resource is available.
5. If drift is detected, run migration/repair to converge state.

## Typical Paths

### 1) Install Skills

1. Select a target provider in the sidebar.
2. Open Resource Center and install the required skill.
3. Confirm availability in the `Skills` tab.

### 2) Configure MCP

1. Open the provider's `MCP` tab.
2. Add or edit MCP entries.
3. Verify config path and runtime status.

### 3) Migrate and Repair

1. Scan unmanaged/orphaned resources.
2. Run migration or broken-link repair.
3. Re-scan and confirm workspace health.

## UI Overview

![Main workspace](docs/assets/readme/main-workspace.png)
Workspace content view: capability tabs + detail panel.

![Resource Center](docs/assets/readme/resource-center.png)
Resource Center: discover and install Skills / Workflows / MCP.

![Provider advanced configuration](docs/assets/readme/provider-advanced.png)
Provider surfaces: advanced configuration panel for provider runtime controls.

![Provider usage dashboard](docs/assets/readme/provider-usage.png)
Provider surfaces: account usage dashboard with token trends and session status.

## Developer Entry

Requirements:
- macOS 15.0+
- Xcode 16.0+

Build:

```bash
git submodule update --init --recursive
./build.sh
```

Or:

```bash
xcodebuild -project nolon.xcodeproj -scheme nolon -configuration Release
```

Providers package tests:

```bash
swift test --package-path libs/Providers
```

## Documentation Index

- Feature specs: [`docs-dev/features/`](docs-dev/features/)
- Engineering docs: [`docs-dev/dev/`](docs-dev/dev/)
- API docs: [`docs-dev/api/`](docs-dev/api/)
- Ops/release docs: [`docs-dev/ops/`](docs-dev/ops/)

## FAQ

### Why centralize resources in `~/.nolon/skills`?

It creates a reusable, migratable, repairable source of truth and removes duplicate maintenance across providers.

### Why no roadmap/changelog in README?

README is intentionally stable and entry-focused. Time-sensitive updates live in `docs-dev/ops/`.

## License

This project is licensed under GNU General Public License v3.0 (GPL-3.0). See [`LICENSE`](LICENSE) for details.
