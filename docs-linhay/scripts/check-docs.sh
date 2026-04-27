#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCS_DIR="${ROOT_DIR}/docs-linhay"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_dir() {
  local path="$1"
  [[ -d "${path}" ]] || fail "missing directory: ${path}"
}

assert_file() {
  local path="$1"
  [[ -f "${path}" ]] || fail "missing file: ${path}"
}

assert_absent() {
  local path="$1"
  [[ ! -e "${path}" ]] || fail "legacy path still exists: ${path}"
}

assert_dir "${DOCS_DIR}"
assert_file "${DOCS_DIR}/README.md"

for dir in spaces dev memory references scripts; do
  assert_dir "${DOCS_DIR}/${dir}"
done

for skill in \
  ".agent/skills/gettokens-session-organize.md" \
  ".agent/skills/gettokens-space-governance.md" \
  ".agent/skills/gettokens-doc-writeback.md" \
  ".agent/skills/gettokens-agents-governance-sync.md"; do
  assert_file "${ROOT_DIR}/${skill}"
done

for legacy in features plans screenshots debate; do
  assert_absent "${DOCS_DIR}/${legacy}"
done

space_count=0
while IFS= read -r -d '' space_dir; do
  space_count=$((space_count + 1))
  space_key="$(basename "${space_dir}")"
  [[ "${space_key}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || fail "invalid space key: ${space_key}"
  assert_file "${space_dir}/README.md"
  assert_dir "${space_dir}/plans"
  assert_dir "${space_dir}/screenshots"
  assert_dir "${space_dir}/debate"
done < <(find "${DOCS_DIR}/spaces" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

[[ "${space_count}" -gt 0 ]] || fail "docs-linhay/spaces is empty"

echo "PASS: docs structure valid"
