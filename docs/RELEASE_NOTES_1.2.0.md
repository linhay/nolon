# Nolon 1.2.0

## What's New

### ✨ Features
- **MCP Web Editor**: MCP cards now open the WebView-based config editor (legacy form editor removed).
- **Per-MCP Migration**: MCP migration is now done one server at a time, with clear “Migrate / Update” actions per card.
- **Standard MCP Cache**: Migrated MCP cache to `~/.nolon/mcps` with “one MCP per file” JSON using the standard `mcpServers` shape.
- **MCP JSON Normalization**: Improved MCP JSON write/read stability (canonical ordering, no escaped slashes, `type` inference for `http` / `stdio`).
- **Environment Variable Expansion**: Added support for `${env:VAR}` and `${env:VAR:-default}` in MCP configs.
- **OpenCode MCP Support Fixes**: Updated OpenCode MCP config path/format handling (now uses `~/.config/opencode/opencode.json`, with top-level `mcp`).

### 🛠 Build & Project
- **Git Submodules**: `libs/` dependencies are now managed via git submodules; build script validates they are populated.
