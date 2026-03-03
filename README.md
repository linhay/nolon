# Nolon

English | [中文](README_ZH.md)

Nolon is a macOS workspace orchestrator for AI coding tools.

It keeps one canonical workspace in `~/.nolon/skills`, then projects that workspace into Codex, Claude Code, Cursor, and 25+ providers with provider-specific behavior.

## Download

- Latest release: [v1.3.5](https://github.com/linhay/nolon/releases/latest)
- Sparkle appcast: [appcast.xml](https://linhay.github.io/nolon/appcast.xml)
- Project site: [GitHub Pages](https://linhay.github.io/nolon/)

## Current App Shape

### 1) Main Workspace (always-on)

Nolon uses a three-column split workspace:
- Provider sidebar
- Provider content tabs
- Detail grid/content panel

### 2) Resource Center (overlay)

The cloud button opens Resource Center as an overlay for remote discovery and install:
- Skills
- Workflows
- MCPs

### 3) Provider-Specific Surfaces

Provider tabs are now capability-driven:
- Base tabs: `Skills`, `Workflows`, `MCP`
- Codex tabs: `Rules`, `Agents`, `Binary`, `Advanced`, `Usage`
- Vendor-defined tabs (when available): `Accounts`, `Usage`, and more

## Core Capabilities

- Unified provider management for 25+ AI coding assistants.
- One-source-of-truth skill storage at `~/.nolon/skills`.
- Remote resource discovery/install from [Clawdhub](https://clawdhub.com).
- MCP configuration management and install flow.
- Codex-focused account/usage and advanced configuration workflows.
- Migration assistant for unmanaged/orphaned skills.
- Health checks and repair for broken links/install drift.

## Typical Workflow

1. Select a provider in the main workspace.
2. Open Resource Center and install Skills/Workflows/MCPs.
3. Configure provider-specific tabs (for example Codex `Advanced`/`Usage`).
4. Run migration/repair checks when drift is detected.
5. Keep app/resources updated through built-in channels.

## Build (Developers)

```bash
git submodule update --init --recursive
./build.sh
```

Or:

```bash
xcodebuild -project nolon.xcodeproj -scheme nolon -configuration Release
```

## Requirements

- macOS 15.0+
- Xcode 16.0+ (for local build)

## Documentation

- Feature specs: [`docs-dev/features/`](docs-dev/features/)
- Engineering docs: [`docs-dev/dev/`](docs-dev/dev/)
- API docs: [`docs-dev/api/`](docs-dev/api/)
- Operations/release docs: [`docs-dev/ops/`](docs-dev/ops/)

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0).
See [`LICENSE`](LICENSE) for details.

## Branch Notes

Current branch merge notes are tracked in:
- [`docs-dev/ops/main-merge-notes-2026-02-27.md`](docs-dev/ops/main-merge-notes-2026-02-27.md)
