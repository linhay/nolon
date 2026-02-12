# Nolon

English | [中文](README_ZH.md)

Nolon is an AI coding workspace manager for macOS.

Use one workspace across **Codex**, **Claude Code**, **Cursor**, and 20+ other providers, instead of reconfiguring each tool separately.

## Why Nolon

* One source of truth for your setup at `~/.nolon/skills`
* Unified management for **skills**, **providers**, and **MCP**
* Fast switching between tools without losing workflow consistency
* Reliable update flow for both app and managed content

## Download

* Latest release: [v1.3.5](https://github.com/linhay/nolon/releases/latest)
* Appcast (Sparkle): [appcast.xml](https://linhay.github.io/nolon/appcast.xml)

## Core Capabilities

* Provider management across 25+ AI coding assistants
* Per-provider install mode: **symlink** or **copy**
* Remote discovery and install from [Clawdhub](https://clawdhub.com)
* MCP configuration and remote MCP install flows
* Migration assistant for unmanaged/orphaned skills
* Health checks and repair for broken links/install drift
* Skills update checks and in-app app updates

## Typical Workflow

1. Import or sync skills into Nolon.
2. Install to one or more providers.
3. Manage MCP and provider-specific configuration.
4. Run migration/repair when drift is detected.
5. Keep app and content updated from built-in update channels.

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

* macOS 15.0+
* Xcode 16.0+ (for building)
