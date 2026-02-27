#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="${ROOT_DIR}/scripts/install-nolon-cli.sh"
PACKAGE_PATH="${ROOT_DIR}/libs/Providers"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_executable() {
  local path="$1"
  [[ -x "${path}" ]] || fail "expected executable file: ${path}"
}

run_case_default_install() {
  local tmp_home
  tmp_home="$(mktemp -d)"
  local target="${tmp_home}/.nolon/bin/nolon"

  HOME="${tmp_home}" bash "${SCRIPT_PATH}" --package-path "${PACKAGE_PATH}" --configuration debug >/dev/null
  assert_file_executable "${target}"
}

run_case_nolon_home_install() {
  local tmp_root
  tmp_root="$(mktemp -d)"
  local target="${tmp_root}/isolated/bin/nolon"

  NOLON_HOME="${tmp_root}/isolated" bash "${SCRIPT_PATH}" --package-path "${PACKAGE_PATH}" --configuration debug >/dev/null
  assert_file_executable "${target}"
}

run_case_default_overwrite() {
  local tmp_root
  tmp_root="$(mktemp -d)"
  local target_root="${tmp_root}/isolated"
  local target="${target_root}/bin/nolon"

  bash "${SCRIPT_PATH}" --nolon-home "${target_root}" --package-path "${PACKAGE_PATH}" --configuration debug >/dev/null
  printf '#!/usr/bin/env bash\necho stale\n' > "${target}"
  chmod +x "${target}"
  bash "${SCRIPT_PATH}" --nolon-home "${target_root}" --package-path "${PACKAGE_PATH}" --configuration debug >/dev/null
  if "${target}" 2>/dev/null | grep -q "stale"; then
    fail "expected default install to overwrite stale file"
  fi
  assert_file_executable "${target}"
}

run_case_force_overwrite() {
  local tmp_root
  tmp_root="$(mktemp -d)"
  local target_root="${tmp_root}/isolated"
  local target="${target_root}/bin/nolon"

  bash "${SCRIPT_PATH}" --nolon-home "${target_root}" --package-path "${PACKAGE_PATH}" --configuration debug >/dev/null
  printf '#!/usr/bin/env bash\necho stale\n' > "${target}"
  chmod +x "${target}"

  bash "${SCRIPT_PATH}" --nolon-home "${target_root}" --package-path "${PACKAGE_PATH}" --configuration debug --force >/dev/null
  assert_file_executable "${target}"
  if "${target}" 2>/dev/null | grep -q "stale"; then
    fail "expected --force install to overwrite stale file"
  fi
}

run_case_no_force_fails() {
  local tmp_root
  tmp_root="$(mktemp -d)"
  local target_root="${tmp_root}/isolated"
  local target="${target_root}/bin/nolon"

  bash "${SCRIPT_PATH}" --nolon-home "${target_root}" --package-path "${PACKAGE_PATH}" --configuration debug >/dev/null
  if bash "${SCRIPT_PATH}" --nolon-home "${target_root}" --package-path "${PACKAGE_PATH}" --configuration debug --no-force >/tmp/install_nolon_cli_smoke.err 2>&1; then
    fail "expected second install with --no-force to fail"
  fi

  grep -q "already exists" /tmp/install_nolon_cli_smoke.err || fail "expected conflict error message"
  assert_file_executable "${target}"
}

run_case_print_path() {
  local tmp_root
  tmp_root="$(mktemp -d)"
  local target_root="${tmp_root}/isolated"
  local expected="${target_root}/bin/nolon"
  local output

  output="$(bash "${SCRIPT_PATH}" --nolon-home "${target_root}" --package-path "${PACKAGE_PATH}" --configuration debug --print-path)"
  [[ "${output}" == "${expected}" ]] || fail "expected print-path output ${expected}, got ${output}"
}

run_case_installed_binary_executes_codex_help() {
  local tmp_root
  tmp_root="$(mktemp -d)"
  local target_root="${tmp_root}/isolated"
  local target="${target_root}/bin/nolon"

  bash "${SCRIPT_PATH}" --nolon-home "${target_root}" --package-path "${PACKAGE_PATH}" --configuration debug >/dev/null
  assert_file_executable "${target}"

  local root_help
  root_help="$("${target}" --help)"
  grep -q "USAGE: nolon <subcommand>" <<<"${root_help}" || fail "expected root help usage output"
  grep -q "codex" <<<"${root_help}" || fail "expected root help to include codex subcommand"

  local codex_help
  codex_help="$("${target}" codex --help)"
  grep -q "USAGE: nolon codex <subcommand>" <<<"${codex_help}" || fail "expected codex help usage output"
  grep -q "auth" <<<"${codex_help}" || fail "expected codex help to include auth subcommand"
  grep -q "binary" <<<"${codex_help}" || fail "expected codex help to include binary subcommand"

  local probe_help
  probe_help="$("${target}" codex status probe --help)"
  grep -q "USAGE: nolon codex status probe" <<<"${probe_help}" || fail "expected status probe help usage output"
}

main() {
  [[ -f "${SCRIPT_PATH}" ]] || fail "install script missing: ${SCRIPT_PATH}"
  run_case_default_install
  run_case_nolon_home_install
  run_case_default_overwrite
  run_case_force_overwrite
  run_case_no_force_fails
  run_case_print_path
  run_case_installed_binary_executes_codex_help
  echo "PASS: install-nolon-cli smoke"
}

main "$@"
