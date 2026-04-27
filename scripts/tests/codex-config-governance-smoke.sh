#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

SOURCE_PATHS=(
  "libs/Providers/Sources"
  "nolon/Skills/Domain"
)

PATTERNS=(
  '(?s)let\s+\w*config\w*\s*=.*?(defaultMcpConfigPath|file\("config\.toml"\)).{0,500}?(overlay\(with:|write\(to:)'
  '(?s)let\s+path\s*=.*defaultMcpConfigPath\.path.{0,500}?(overlay\(with:|write\(to:)'
)

for pattern in "${PATTERNS[@]}"; do
  if rg -nUP "${pattern}" "${SOURCE_PATHS[@]}"; then
    echo "FAIL: found direct Codex config write bypass; route through CodexConfigStore or MCPConfigManager" >&2
    exit 1
  fi
done

echo "PASS: no direct Codex config write bypasses found"
