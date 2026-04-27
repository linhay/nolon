#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOCS_DIR="${ROOT_DIR}/docs-linhay"
CREATE_SPACE_SCRIPT="${DOCS_DIR}/scripts/create-space.sh"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

require_dir() {
  local path="$1"
  [[ -d "${path}" ]] || fail "missing directory: ${path}"
}

feature_to_space() {
  local file_name="$1"
  local stem="${file_name%.md}"
  if [[ "${stem}" =~ ^(.+)-[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
  else
    printf '%s\n' "${stem}"
  fi
}

PATH_MAPPING_OLDS=()
PATH_MAPPING_NEWS=()

register_mapping() {
  local old_rel="$1"
  local new_rel="$2"
  PATH_MAPPING_OLDS+=("${old_rel}")
  PATH_MAPPING_NEWS+=("${new_rel}")
}

module_fallback_space() {
  local module="$1"
  case "${module}" in
    codex-sessions) printf '%s\n' "codex-sessions-tab" ;;
    provider-usage) printf '%s\n' "provider-account-usage-tab-split" ;;
    resource-center) printf '%s\n' "skill-install-nonstandard-symlink-layout" ;;
    codex-accounts) printf '%s\n' "codex-auth-preflight-and-drift-repair" ;;
    codex-usage) printf '%s\n' "provider-usage-intraday-drilldown" ;;
    codex-mcp) printf '%s\n' "plugin-management-xcodemcpkit" ;;
    *) printf '%s\n' "nolon-core-cli-milestones" ;;
  esac
}

default_screenshot_space() {
  local module="$1"
  case "${module}" in
    codex) printf '%s\n' "codex-account-usage-tab-update" ;;
    resource-center) printf '%s\n' "resource-center-delete-and-text-selection" ;;
    codex-gateway|gateway) printf '%s\n' "codex-account-pool-gateway-and-autoswitch" ;;
    provider-usage) printf '%s\n' "provider-account-usage-tab-split" ;;
    misc) printf '%s\n' "codex-account-usage-tab-update" ;;
    *) printf '%s\n' "nolon-core-cli-milestones" ;;
  esac
}

first_feature_ref() {
  local path="$1"
  rg -o "docs-linhay/features/[^)[:space:]]+\\.md" -m 1 "${path}" 2>/dev/null | head -n 1 | sed 's#^docs-linhay/features/##'
}

space_from_ref_or_fallback() {
  local path="$1"
  local fallback="$2"
  local feature_ref
  feature_ref="$(first_feature_ref "${path}" || true)"
  if [[ -n "${feature_ref}" ]]; then
    feature_to_space "${feature_ref}"
    return
  fi
  printf '%s\n' "${fallback}"
}

move_feature_docs() {
  local features_dir="${DOCS_DIR}/features"
  [[ -d "${features_dir}" ]] || return

  while IFS= read -r feature_path; do
    local feature_name
    feature_name="$(basename "${feature_path}")"
    local space_key
    space_key="$(feature_to_space "${feature_name}")"
    bash "${CREATE_SPACE_SCRIPT}" "${space_key}" >/dev/null

    local target_rel="docs-linhay/spaces/${space_key}/README.md"
    local target_path="${ROOT_DIR}/${target_rel}"
    [[ ! -f "${target_path}" || "${target_path}" == "${feature_path}" ]] || rm -f "${target_path}"
    mv "${feature_path}" "${target_path}"
    register_mapping "docs-linhay/features/${feature_name}" "${target_rel}"
  done < <(find "${features_dir}" -maxdepth 1 -type f -name '*.md' ! -name 'README.md' | sort)
}

move_plan_docs() {
  local plans_dir="${DOCS_DIR}/plans"
  [[ -d "${plans_dir}" ]] || return

  while IFS= read -r plan_path; do
    local plan_name
    plan_name="$(basename "${plan_path}")"
    [[ "${plan_name}" == ".gitkeep" ]] && continue
    local fallback_space="nolon-core-cli-milestones"
    if [[ "${plan_name}" == *"codex-sessions"* ]]; then
      fallback_space="codex-sessions-tab"
    elif [[ "${plan_name}" == *"provider-usage"* ]]; then
      fallback_space="provider-account-usage-tab-split"
    elif [[ "${plan_name}" == *"resource-center"* || "${plan_name}" == *"skill-install"* ]]; then
      fallback_space="skill-install-nonstandard-symlink-layout"
    elif [[ "${plan_name}" == *"ui-migration"* ]]; then
      fallback_space="main-site-flowdown-refresh"
    elif [[ "${plan_name}" == *"codex-usage"* ]]; then
      fallback_space="codex-account-usage-tab-update"
    fi

    local space_key
    space_key="$(space_from_ref_or_fallback "${plan_path}" "${fallback_space}")"
    bash "${CREATE_SPACE_SCRIPT}" "${space_key}" >/dev/null

    local target_rel="docs-linhay/spaces/${space_key}/plans/${plan_name}"
    mv "${plan_path}" "${ROOT_DIR}/${target_rel}"
    register_mapping "docs-linhay/plans/${plan_name}" "${target_rel}"
  done < <(find "${plans_dir}" -maxdepth 1 -type f | sort)

  rm -f "${plans_dir}/.gitkeep" 2>/dev/null || true
}

move_debate_docs() {
  local debate_dir="${DOCS_DIR}/debate"
  [[ -d "${debate_dir}" ]] || return

  while IFS= read -r debate_path; do
    local debate_rel="${debate_path#${DOCS_DIR}/debate/}"
    local module
    module="$(printf '%s\n' "${debate_rel}" | cut -d/ -f2)"
    local fallback_space
    fallback_space="$(module_fallback_space "${module}")"
    local space_key
    space_key="$(space_from_ref_or_fallback "${debate_path}" "${fallback_space}")"
    bash "${CREATE_SPACE_SCRIPT}" "${space_key}" >/dev/null

    local target_rel="docs-linhay/spaces/${space_key}/debate/${debate_rel}"
    mkdir -p "$(dirname "${ROOT_DIR}/${target_rel}")"
    mv "${debate_path}" "${ROOT_DIR}/${target_rel}"
    register_mapping "docs-linhay/debate/${debate_rel}" "${target_rel}"
  done < <(find "${debate_dir}" -type f -name '*.md' ! -name 'README.md' | sort)
}

space_from_screenshot() {
  local screenshot_rel="$1"
  local module
  module="$(printf '%s\n' "${screenshot_rel}" | cut -d/ -f2)"
  local file_name
  file_name="$(basename "${screenshot_rel}")"

  case "${file_name}" in
    *refresh-interrupt*)
      printf '%s\n' "codex-account-usage-refresh-interrupt"
      ;;
    *gateway*)
      printf '%s\n' "codex-account-pool-gateway-and-autoswitch"
      ;;
    *usage*)
      printf '%s\n' "codex-account-usage-tab-update"
      ;;
    *)
      default_screenshot_space "${module}"
      ;;
  esac
}

move_screenshots() {
  local screenshots_dir="${DOCS_DIR}/screenshots"
  [[ -d "${screenshots_dir}" ]] || return

  while IFS= read -r screenshot_path; do
    local screenshot_rel="${screenshot_path#${DOCS_DIR}/screenshots/}"
    [[ "${screenshot_rel}" == "README.md" ]] && continue
    local space_key
    space_key="$(space_from_screenshot "${screenshot_rel}")"
    bash "${CREATE_SPACE_SCRIPT}" "${space_key}" >/dev/null

    local target_rel="docs-linhay/spaces/${space_key}/screenshots/${screenshot_rel}"
    mkdir -p "$(dirname "${ROOT_DIR}/${target_rel}")"
    mv "${screenshot_path}" "${ROOT_DIR}/${target_rel}"
    register_mapping "docs-linhay/screenshots/${screenshot_rel}" "${target_rel}"
  done < <(find "${screenshots_dir}" -type f | sort)
}

rewrite_links() {
  local markdown_paths=()
  while IFS= read -r path; do
    markdown_paths+=("${path}")
  done < <(find "${DOCS_DIR}" -type f -name '*.md' ! -path "${DOCS_DIR}/references/*" | sort)

  local perl_expr=""
  local i
  for ((i = 0; i < ${#PATH_MAPPING_OLDS[@]}; i++)); do
    local old_rel="${PATH_MAPPING_OLDS[$i]}"
    local new_rel="${PATH_MAPPING_NEWS[$i]}"
    local old_abs="${ROOT_DIR}/${old_rel}"
    local new_abs="${ROOT_DIR}/${new_rel}"
    perl_expr="${perl_expr}s#\\Q${old_rel}\\E#${new_rel}#g; s#\\Q${old_abs}\\E#${new_abs}#g; "
  done

  local path
  for path in "${markdown_paths[@]}"; do
    perl -0pi -e "${perl_expr}" "${path}"
  done
}

cleanup_legacy_dirs() {
  rm -f "${DOCS_DIR}/features/README.md" "${DOCS_DIR}/plans/README.md" \
    "${DOCS_DIR}/debate/README.md" "${DOCS_DIR}/screenshots/README.md" 2>/dev/null || true
  rmdir "${DOCS_DIR}/features" "${DOCS_DIR}/plans" "${DOCS_DIR}/screenshots" 2>/dev/null || true

  find "${DOCS_DIR}/debate" -type d -empty -delete 2>/dev/null || true
  find "${DOCS_DIR}/screenshots" -type d -empty -delete 2>/dev/null || true
  rmdir "${DOCS_DIR}/debate" 2>/dev/null || true
  rmdir "${DOCS_DIR}/screenshots" 2>/dev/null || true
}

main() {
  require_dir "${DOCS_DIR}"
  require_dir "${DOCS_DIR}/scripts"
  require_dir "${DOCS_DIR}/dev"
  require_dir "${DOCS_DIR}/memory"
  require_dir "${DOCS_DIR}/references"
  mkdir -p "${DOCS_DIR}/spaces"

  move_feature_docs
  move_plan_docs
  move_debate_docs
  move_screenshots
  rewrite_links
  cleanup_legacy_dirs
}

main "$@"
