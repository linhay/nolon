#!/bin/bash

set -euo pipefail

INFO_PLIST_PATH="${INFO_PLIST_PATH:-nolon/Info.plist}"
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:-temp_sparkle/bin}"
KEYCHAIN_ACCOUNT="${SPARKLE_KEYCHAIN_ACCOUNT:-ed25519}"

if [ ! -f "$INFO_PLIST_PATH" ]; then
    echo "❌ Info.plist not found: $INFO_PLIST_PATH" >&2
    exit 1
fi

EXPECTED_PUBLIC_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$INFO_PLIST_PATH" 2>/dev/null || true)

if [ -z "$EXPECTED_PUBLIC_KEY" ]; then
    echo "❌ SUPublicEDKey is missing from $INFO_PLIST_PATH" >&2
    exit 1
fi

resolve_private_key_public_key() {
    SPARKLE_PRIVATE_KEY_VALUE="$SPARKLE_PRIVATE_KEY" swift - <<'SWIFT'
import CryptoKit
import Foundation

let env = ProcessInfo.processInfo.environment
let privateKey = env["SPARKLE_PRIVATE_KEY_VALUE"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

guard let seed = Data(base64Encoded: privateKey) else {
    fputs("❌ SPARKLE_PRIVATE_KEY is not valid base64.\n", stderr)
    exit(1)
}

do {
    let key = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
    print(key.publicKey.rawRepresentation.base64EncodedString())
} catch {
    fputs("❌ Failed to derive Sparkle public key from SPARKLE_PRIVATE_KEY: \(error)\n", stderr)
    exit(1)
}
SWIFT
}

if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
    ACTUAL_PUBLIC_KEY="$(resolve_private_key_public_key)"
    KEY_SOURCE="SPARKLE_PRIVATE_KEY"
else
    if [ ! -x "${SPARKLE_BIN_DIR}/generate_keys" ]; then
        echo "❌ Sparkle generate_keys not found: ${SPARKLE_BIN_DIR}/generate_keys" >&2
        exit 1
    fi

    ACTUAL_PUBLIC_KEY="$("${SPARKLE_BIN_DIR}/generate_keys" --account "$KEYCHAIN_ACCOUNT" -p | tail -n 1 | tr -d '\r')"
    KEY_SOURCE="keychain:${KEYCHAIN_ACCOUNT}"
fi

if [ "$ACTUAL_PUBLIC_KEY" != "$EXPECTED_PUBLIC_KEY" ]; then
    echo "❌ Sparkle key mismatch." >&2
    echo "   expected (Info.plist): $EXPECTED_PUBLIC_KEY" >&2
    echo "   actual   (${KEY_SOURCE}): $ACTUAL_PUBLIC_KEY" >&2
    exit 1
fi

echo "✅ Sparkle key matches SUPublicEDKey (${KEY_SOURCE})"
