#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DEFAULT_PACKAGE_PATH="${ROOT_DIR}/libs/Providers"
DEFAULT_CONFIGURATION="release"
NOLON_HOME_ENV_NAME="NOLON_HOME"
INSTALL_BIN_DIR_NAME="bin"
INSTALL_BINARY_NAME="nolon"

package_path="${DEFAULT_PACKAGE_PATH}"
configuration="${DEFAULT_CONFIGURATION}"
nolon_home=""
force_overwrite="0"
print_path_only="0"

usage() {
  cat <<EOF
Usage: scripts/install-nolon-cli.sh [options]

Options:
  --nolon-home <path>     Install root. Default: \$NOLON_HOME or ~/.nolon
  --package-path <path>   Swift package path. Default: ${DEFAULT_PACKAGE_PATH}
  --configuration <name>  Build configuration: release|debug (default: ${DEFAULT_CONFIGURATION})
  --force                 Overwrite existing target binary
  --print-path            Print installed binary path only
  -h, --help              Show this help
EOF
}

error() {
  echo "Error: $*" >&2
  exit 1
}

resolve_nolon_home() {
  if [[ -n "${nolon_home}" ]]; then
    echo "${nolon_home}"
    return
  fi
  if [[ -n "${!NOLON_HOME_ENV_NAME:-}" ]]; then
    echo "${!NOLON_HOME_ENV_NAME}"
    return
  fi
  echo "${HOME}/.nolon"
}

normalize_abs_path() {
  local raw="$1"
  python3 - <<'PY' "$raw"
import os
import sys

print(os.path.abspath(os.path.expanduser(sys.argv[1])))
PY
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --nolon-home)
        [[ $# -ge 2 ]] || error "Missing value for --nolon-home"
        nolon_home="$2"
        shift 2
        ;;
      --package-path)
        [[ $# -ge 2 ]] || error "Missing value for --package-path"
        package_path="$2"
        shift 2
        ;;
      --configuration)
        [[ $# -ge 2 ]] || error "Missing value for --configuration"
        configuration="$2"
        shift 2
        ;;
      --force)
        force_overwrite="1"
        shift
        ;;
      --print-path)
        print_path_only="1"
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Unsupported option: $1"
        ;;
    esac
  done
}

validate_inputs() {
  [[ -d "${package_path}" ]] || error "Package path not found: ${package_path}"
  [[ "${configuration}" == "release" || "${configuration}" == "debug" ]] \
    || error "Unsupported --configuration: ${configuration} (expected release|debug)"
}

build_binary() {
  swift build \
    --package-path "${package_path}" \
    -c "${configuration}" \
    --product "${INSTALL_BINARY_NAME}" >/dev/null
}

resolve_built_binary_path() {
  local bin_path
  if bin_path="$(swift build --package-path "${package_path}" -c "${configuration}" --show-bin-path 2>/dev/null)"; then
    local primary="${bin_path}/${INSTALL_BINARY_NAME}"
    if [[ -x "${primary}" ]]; then
      echo "${primary}"
      return
    fi
  fi

  local fallback
  fallback="$(find "${package_path}/.build" -type f -name "${INSTALL_BINARY_NAME}" -perm -u+x | head -n 1 || true)"
  [[ -n "${fallback}" ]] || error "Built binary not found under ${package_path}/.build"
  echo "${fallback}"
}

install_binary() {
  local source_binary="$1"
  local target_binary="$2"

  mkdir -p "$(dirname "${target_binary}")"
  if [[ -e "${target_binary}" && "${force_overwrite}" != "1" ]]; then
    error "Target already exists: ${target_binary} (use --force to overwrite)"
  fi
  cp -f "${source_binary}" "${target_binary}"
  chmod +x "${target_binary}"
}

print_result() {
  local target_binary="$1"
  if [[ "${print_path_only}" == "1" ]]; then
    echo "${target_binary}"
    return
  fi

  echo "Installed: ${target_binary}"
  local target_bin_dir
  target_bin_dir="$(dirname "${target_binary}")"
  if [[ ":${PATH}:" != *":${target_bin_dir}:"* ]]; then
    echo "Hint: add to PATH -> export PATH=\"${target_bin_dir}:\$PATH\""
  fi
}

main() {
  parse_args "$@"
  validate_inputs

  local resolved_home
  resolved_home="$(normalize_abs_path "$(resolve_nolon_home)")"
  local target_binary="${resolved_home}/${INSTALL_BIN_DIR_NAME}/${INSTALL_BINARY_NAME}"

  build_binary
  local source_binary
  source_binary="$(resolve_built_binary_path)"
  install_binary "${source_binary}" "${target_binary}"
  print_result "${target_binary}"
}

main "$@"
