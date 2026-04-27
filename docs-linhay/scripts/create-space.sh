#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCS_DIR="${ROOT_DIR}/docs-linhay"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: docs-linhay/scripts/create-space.sh <space-key> [--title <title>]

Creates a docs-linhay space with:
- README.md
- plans/
- screenshots/
- debate/
EOF
}

SPACE_KEY="${1:-}"
[[ -n "${SPACE_KEY}" ]] || {
  usage >&2
  fail "space-key is required"
}

shift || true

TITLE="${SPACE_KEY}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --title)
      shift || fail "--title requires a value"
      [[ $# -gt 0 ]] || fail "--title requires a value"
      TITLE="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
  shift || true
done

[[ "${SPACE_KEY}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid space-key: ${SPACE_KEY}"

SPACE_DIR="${DOCS_DIR}/spaces/${SPACE_KEY}"
README_PATH="${SPACE_DIR}/README.md"

mkdir -p "${SPACE_DIR}/plans" "${SPACE_DIR}/screenshots" "${SPACE_DIR}/debate"

if [[ ! -f "${README_PATH}" ]]; then
  cat > "${README_PATH}" <<EOF
# ${TITLE}

## 背景
- 待补充

## 目标
- 待补充

## 范围
- 待补充

## 验收标准
1. 待补充

## 关联文档
- 待补充
EOF
fi

printf '%s\n' "${SPACE_DIR}"
