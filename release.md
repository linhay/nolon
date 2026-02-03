# Nolon 1.2.0

## Highlights
- MCP cards now open the WebView-based config editor (legacy form editor removed).
- MCP migration is now done one server at a time, with clear “Migrate / Update” actions per card.
- MCP cache is standardized to `~/.nolon/mcps` using “one MCP per file” JSON (`mcpServers` shape).
- MCP JSON is normalized for stable read/write (canonical ordering, no escaped slashes, `type` inference for `http` / `stdio`).
- Added support for `${env:VAR}` and `${env:VAR:-default}` expansion in MCP configs.
- OpenCode MCP handling updated to match OpenCode’s config (`~/.config/opencode/opencode.json`, top-level `mcp`).

## Build & Project
- `libs/` dependencies are now managed via git submodules; build script validates they are populated.

