#!/bin/bash
# Sync release config/secrets to a self-hosted macOS runner.
#
# Usage:
#   ./scripts/sync-release-secrets-to-mini.sh [host]
#
# Default host: mini.lan
# Remote destination: ~/.nolon/release-secrets/release.env
#
# This script never prints secret values.

set -euo pipefail

HOST="${1:-mini.lan}"
REMOTE_DIR='~/.nolon/release-secrets'
REMOTE_FILE="${REMOTE_DIR}/release.env"
LOCAL_ENV_FILE=".env"

TMP_ENV="$(mktemp -t nolon-release-env.XXXXXX)"
cleanup() {
  rm -f "${TMP_ENV}"
}
trap cleanup EXIT

if [ -f "${LOCAL_ENV_FILE}" ]; then
  set -a
  # shellcheck disable=SC1090
  source "${LOCAL_ENV_FILE}"
  set +a
fi

# Optional convenience:
# if user provides MACOS_CERTIFICATE_P12_PATH, convert to base64 automatically.
if [ -z "${MACOS_CERTIFICATE_P12_BASE64:-}" ] && [ -n "${MACOS_CERTIFICATE_P12_PATH:-}" ]; then
  if [ ! -f "${MACOS_CERTIFICATE_P12_PATH}" ]; then
    echo "❌ MACOS_CERTIFICATE_P12_PATH file not found: ${MACOS_CERTIFICATE_P12_PATH}"
    exit 1
  fi
  MACOS_CERTIFICATE_P12_BASE64="$(base64 < "${MACOS_CERTIFICATE_P12_PATH}" | tr -d '\n')"
fi

if [ -z "${SPARKLE_KEYCHAIN_ACCOUNT:-}" ]; then
  SPARKLE_KEYCHAIN_ACCOUNT="ed25519"
fi

emit_var() {
  local key="$1"
  local value="${!key:-}"
  if [ -n "${value}" ]; then
    {
      echo "export ${key}=\$(cat <<'__NOLON_EOF__'"
      printf '%s\n' "${value}"
      echo "__NOLON_EOF__"
      echo ")"
    } >> "${TMP_ENV}"
    return 0
  fi
  return 1
}

echo "# Generated at $(date '+%Y-%m-%d %H:%M:%S %z')" > "${TMP_ENV}"
echo "# Synced by scripts/sync-release-secrets-to-mini.sh" >> "${TMP_ENV}"

synced_keys=()
missing_keys=()

for key in \
  SPARKLE_PRIVATE_KEY \
  SPARKLE_KEYCHAIN_ACCOUNT \
  MACOS_CERTIFICATE_P12_BASE64 \
  MACOS_CERTIFICATE_P12_PASSWORD \
  SIGNING_IDENTITY \
  NOTARY_PROFILE \
  APPLE_ID \
  APPLE_APP_PASSWORD \
  TEAM_ID
do
  if emit_var "${key}"; then
    synced_keys+=("${key}")
  else
    missing_keys+=("${key}")
  fi
done

if [ "${#synced_keys[@]}" -eq 0 ]; then
  echo "❌ 没有可同步的发版配置。"
  echo "请先在当前 shell 或 .env 设置至少一个变量。"
  exit 1
fi

echo "🔐 Sync target: ${HOST}:${REMOTE_FILE}"
echo "📦 Keys to sync (${#synced_keys[@]}): ${synced_keys[*]}"

ssh "${HOST}" "mkdir -p ${REMOTE_DIR} && chmod 700 ${REMOTE_DIR}"
scp "${TMP_ENV}" "${HOST}:${REMOTE_FILE}"
ssh "${HOST}" "chmod 600 ${REMOTE_FILE}"

echo "✅ release.env 已同步到 ${HOST}:${REMOTE_FILE}"
if [ "${#missing_keys[@]}" -gt 0 ]; then
  echo "⚠️ 未提供的 keys (${#missing_keys[@]}): ${missing_keys[*]}"
fi
