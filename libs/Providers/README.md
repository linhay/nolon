# Providers

Unified Swift Package for AI coding assistant usage tracking.

## Overview

This package provides a unified interface for fetching usage information from various AI coding assistants:

- **Codex** (OpenAI Codex CLI) - Local CLI-based usage fetching
- **Copilot** (GitHub Copilot) - Remote API-based usage fetching

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "path/to/libs/Providers", from: "1.0.0")
]
```

## Usage

### Option 1: Use Unified Library (All Providers)

```swift
import Providers

// Access both Codex and Copilot
let codexHelper = CodexHelper()
let copilotHelper = CopilotHelper()

// Fetch usage from both
let codexUsage = try await codexHelper.fetchCredits()
let copilotUsage = try await copilotHelper.fetchUsage()
```

### Option 2: Use Individual Providers

```swift
// Only Codex
import CodexProvider

let helper = CodexHelper()
let usage = try await helper.fetchCredits()
```

```swift
// Only Copilot
import CopilotProvider

let helper = CopilotHelper(token: "ghp_xxxx")
let usage = try await helper.fetchUsage()
```

### Option 3: Use `nolon-core` CLI

```bash
# plan repository import
swift run --package-path libs/Providers nolon-core \
  skills repo plan \
  --source vercel/agent-skills/skills/react-best-practices \
  --repositories-root /tmp/nolon-repos

# discover repository resources (skills/workflows/mcp)
swift run --package-path libs/Providers nolon-core \
  resources discover \
  --path libs/agent-skills \
  --max-depth 5
```

## Providers

### CodexProvider

Fetches usage from OpenAI Codex CLI.

**Requirements:**
- Codex CLI installed (`npm i -g @openai/codex`)
- Authenticated with OpenAI

**Features:**
- RPC-based fetching (primary)
- TTY-based fallback
- Automatic CLI session management

```swift
import CodexProvider

let helper = CodexHelper()

// Check if CLI is available
if helper.isCLIAvailable {
    let snapshot = try await helper.fetchCredits()
    print("Remaining: \(snapshot.remaining)")
}
```

### CopilotProvider

Fetches usage from GitHub Copilot API.

**Requirements:**
- GitHub OAuth token with Copilot scope
- Set `COPILOT_API_TOKEN` environment variable

**Features:**
- Premium interactions quota tracking
- Chat quota tracking
- Plan information (Pro, Business, etc.)

```swift
import CopilotProvider

let helper = CopilotHelper()

if helper.isAuthenticated {
    let usage = try await helper.fetchUsage()
    print("Plan: \(usage.plan)")
    
    if let premium = usage.premiumQuota {
        print("Premium: \(premium.remaining) / \(premium.total)")
    }
    
    if let chat = usage.chatQuota {
        print("Chat: \(chat.remaining) / \(chat.total)")
    }
}
```

## Data Models

### Codex Models

- `CreditsSnapshot` - Remaining credits and usage events
- `CreditEvent` - Individual credit usage event
- `CodexStatusSnapshot` - Full status including rate limits

### Copilot Models

- `CopilotUsageSnapshot` - Complete usage information
- `CopilotQuota` - Quota details for a specific feature
- `CopilotUsageResponse` - Raw API response

## Error Handling

### Codex Errors

- `CodexStatusProbeError` - CLI not installed, parse failures, timeouts
- `CreditsFetchError` - RPC errors, token issues

### Copilot Errors

- `CopilotUsageError` - Invalid token, network errors, API errors

## Testing

```bash
cd libs/Providers
swift test
```

### Live smoke tests (optional)

By default, tests are skipped unless explicitly enabled (so CI/dev machines without credentials don’t fail).

```bash
RUN_LIVE_PROVIDER_TESTS=1 swift test
```

To also run the Copilot live test:

```bash
RUN_LIVE_PROVIDER_TESTS=1 COPILOT_API_TOKEN=... swift test
```

## License

MIT
