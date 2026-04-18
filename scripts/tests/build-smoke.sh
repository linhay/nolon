#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="${ROOT_DIR}/build.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_line_count() {
  local expected="$1"
  local pattern="$2"
  local file="$3"
  local actual
  actual="$(grep -c -- "${pattern}" "${file}" || true)"
  [[ "${actual}" == "${expected}" ]] || fail "expected ${expected} matches for '${pattern}', got ${actual}"
}

assert_absent() {
  local pattern="$1"
  local file="$2"
  if grep -q -- "${pattern}" "${file}"; then
    fail "expected '${pattern}' to be absent"
  fi
}

make_fake_xcodebuild() {
  local tmp_dir="$1"
  local fake_bin="${tmp_dir}/fake-xcodebuild.sh"
  cat > "${fake_bin}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' '---' >> "${FAKE_XCODEBUILD_LOG}"
printf '%s\n' "$@" >> "${FAKE_XCODEBUILD_LOG}"
EOF
  chmod +x "${fake_bin}"
  printf '%s\n' "${fake_bin}"
}

run_case_default_offline_flags_apply_to_build_and_test() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local log_path="${tmp_dir}/xcodebuild.log"
  local fake_bin
  fake_bin="$(make_fake_xcodebuild "${tmp_dir}")"

  FAKE_XCODEBUILD_LOG="${log_path}" \
    XCODEBUILD_BIN="${fake_bin}" \
    RUN_TESTS=1 \
    TEST_SCOPE=unit \
    bash "${SCRIPT_PATH}" >/dev/null

  assert_line_count 2 '^-skipPackageUpdates$' "${log_path}"
  assert_line_count 2 '^---$' "${log_path}"
}

run_case_no_spm_update_opt_out_removes_flags() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local log_path="${tmp_dir}/xcodebuild.log"
  local fake_bin
  fake_bin="$(make_fake_xcodebuild "${tmp_dir}")"

  FAKE_XCODEBUILD_LOG="${log_path}" \
    XCODEBUILD_BIN="${fake_bin}" \
    NO_SPM_UPDATE=0 \
    RUN_TESTS=0 \
    bash "${SCRIPT_PATH}" >/dev/null

  assert_absent '^-skipPackageUpdates$' "${log_path}"
}

run_case_derived_data_path_is_shared() {
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  local log_path="${tmp_dir}/xcodebuild.log"
  local fake_bin
  fake_bin="$(make_fake_xcodebuild "${tmp_dir}")"
  local derived_data_path="${tmp_dir}/DerivedData"

  FAKE_XCODEBUILD_LOG="${log_path}" \
    XCODEBUILD_BIN="${fake_bin}" \
    DERIVED_DATA_PATH="${derived_data_path}" \
    RUN_TESTS=1 \
    TEST_SCOPE=unit \
    bash "${SCRIPT_PATH}" >/dev/null

  assert_line_count 2 '^-derivedDataPath$' "${log_path}"
  assert_line_count 2 "^${derived_data_path}$" "${log_path}"
}

main() {
  [[ -f "${SCRIPT_PATH}" ]] || fail "build script missing: ${SCRIPT_PATH}"
  run_case_default_offline_flags_apply_to_build_and_test
  run_case_no_spm_update_opt_out_removes_flags
  run_case_derived_data_path_is_shared
  echo "PASS: build smoke"
}

main "$@"
