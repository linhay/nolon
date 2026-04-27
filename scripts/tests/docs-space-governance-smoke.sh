#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
FIXTURE_ROOT="${TMP_DIR}/repo"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "${path}" ]] || fail "expected file: ${path}"
}

assert_dir() {
  local path="$1"
  [[ -d "${path}" ]] || fail "expected directory: ${path}"
}

assert_absent() {
  local path="$1"
  [[ ! -e "${path}" ]] || fail "expected path to be absent: ${path}"
}

setup_fixture() {
  mkdir -p "${FIXTURE_ROOT}/docs-linhay"/{features,plans,debate/20260425/alpha-module,screenshots/20260425/alpha-module,dev,memory,references,scripts}
  mkdir -p "${FIXTURE_ROOT}/.agent/skills"
  cp "${ROOT_DIR}/docs-linhay/scripts/create-space.sh" "${FIXTURE_ROOT}/docs-linhay/scripts/create-space.sh"
  cp "${ROOT_DIR}/docs-linhay/scripts/check-docs.sh" "${FIXTURE_ROOT}/docs-linhay/scripts/check-docs.sh"
  cp "${ROOT_DIR}/docs-linhay/scripts/migrate-docs-to-spaces.sh" "${FIXTURE_ROOT}/docs-linhay/scripts/migrate-docs-to-spaces.sh"
  chmod +x "${FIXTURE_ROOT}/docs-linhay/scripts/"*.sh

  for skill in \
    gettokens-session-organize \
    gettokens-space-governance \
    gettokens-doc-writeback \
    gettokens-agents-governance-sync; do
    cat > "${FIXTURE_ROOT}/.agent/skills/${skill}.md" <<EOF
# ${skill}
EOF
  done

  cat > "${FIXTURE_ROOT}/docs-linhay/README.md" <<'EOF'
# docs-linhay
EOF
  cat > "${FIXTURE_ROOT}/docs-linhay/features/alpha-feature-2026-04-25.md" <<'EOF'
# alpha-feature

截图目录：`screenshots/20260425/alpha-module/`
EOF
  cat > "${FIXTURE_ROOT}/docs-linhay/plans/2026-04-25-alpha-exec.md" <<'EOF'
# alpha-plan

- `docs-linhay/features/alpha-feature-2026-04-25.md`
EOF
  cat > "${FIXTURE_ROOT}/docs-linhay/debate/20260425/alpha-module/20260425-alpha-v01.md" <<'EOF'
# alpha-debate

- `docs-linhay/features/alpha-feature-2026-04-25.md`
EOF
  cat > "${FIXTURE_ROOT}/docs-linhay/dev/alpha-dev.md" <<'EOF'
# alpha-dev

- `docs-linhay/features/alpha-feature-2026-04-25.md`
- `docs-linhay/plans/2026-04-25-alpha-exec.md`
- `docs-linhay/debate/20260425/alpha-module/20260425-alpha-v01.md`
EOF
  printf 'fake-png' > "${FIXTURE_ROOT}/docs-linhay/screenshots/20260425/alpha-module/20260425-alpha-module-baseline-v01.png"
}

run_case_create_space() {
  local output
  output="$(cd "${FIXTURE_ROOT}" && bash docs-linhay/scripts/create-space.sh beta-space)"
  [[ "${output}" == "${FIXTURE_ROOT}/docs-linhay/spaces/beta-space" ]] || fail "unexpected create-space output"
  assert_file "${FIXTURE_ROOT}/docs-linhay/spaces/beta-space/README.md"
  assert_dir "${FIXTURE_ROOT}/docs-linhay/spaces/beta-space/plans"
  assert_dir "${FIXTURE_ROOT}/docs-linhay/spaces/beta-space/screenshots"
  assert_dir "${FIXTURE_ROOT}/docs-linhay/spaces/beta-space/debate"
}

run_case_migration_and_check() {
  (
    cd "${FIXTURE_ROOT}"
    bash docs-linhay/scripts/migrate-docs-to-spaces.sh
    bash docs-linhay/scripts/check-docs.sh
  ) >/dev/null

  assert_file "${FIXTURE_ROOT}/docs-linhay/spaces/alpha-feature/README.md"
  assert_file "${FIXTURE_ROOT}/docs-linhay/spaces/alpha-feature/plans/2026-04-25-alpha-exec.md"
  assert_file "${FIXTURE_ROOT}/docs-linhay/spaces/alpha-feature/debate/20260425/alpha-module/20260425-alpha-v01.md"
  assert_file "${FIXTURE_ROOT}/docs-linhay/spaces/nolon-core-cli-milestones/screenshots/20260425/alpha-module/20260425-alpha-module-baseline-v01.png"
  assert_absent "${FIXTURE_ROOT}/docs-linhay/features"
  assert_absent "${FIXTURE_ROOT}/docs-linhay/plans"
  assert_absent "${FIXTURE_ROOT}/docs-linhay/debate"
  assert_absent "${FIXTURE_ROOT}/docs-linhay/screenshots"

  grep -q "docs-linhay/spaces/alpha-feature/README.md" "${FIXTURE_ROOT}/docs-linhay/dev/alpha-dev.md" || fail "expected feature link rewrite"
  grep -q "docs-linhay/spaces/alpha-feature/plans/2026-04-25-alpha-exec.md" "${FIXTURE_ROOT}/docs-linhay/dev/alpha-dev.md" || fail "expected plan link rewrite"
  grep -q "docs-linhay/spaces/alpha-feature/debate/20260425/alpha-module/20260425-alpha-v01.md" "${FIXTURE_ROOT}/docs-linhay/dev/alpha-dev.md" || fail "expected debate link rewrite"
}

main() {
  setup_fixture
  run_case_create_space
  run_case_migration_and_check
  echo "PASS: docs-space-governance smoke"
}

main "$@"
