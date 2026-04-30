#!/bin/bash
# Build and package nolon.app as DMG for specific or all architectures
# Usage: ./scripts/build-dmg.sh [arch]
# Examples:
#   ./scripts/build-dmg.sh           # Build for current architecture
#   ./scripts/build-dmg.sh arm64     # Build for Apple Silicon
#   ./scripts/build-dmg.sh x86_64    # Build for Intel
#   ./scripts/build-dmg.sh all       # Build for both architectures

set -e

# Configuration
APP_NAME="nolon"
SCHEME="nolon-app"
PROJECT="nolon.xcodeproj"
RELEASE_DIR="release"
BUILD_DIR="${RELEASE_DIR}/build"
APP_ENTITLEMENTS_PATH="nolon/nolon.entitlements"
EMBEDDED_PROVISION_PROFILE_PATH="${EMBEDDED_PROVISION_PROFILE_PATH:-}"
USE_XCODE_OFFICIAL_SIGNING="${USE_XCODE_OFFICIAL_SIGNING:-1}"
XCODE_EXPORT_METHOD="${XCODE_EXPORT_METHOD:-developer-id}"
XCODE_TEAM_ID="${XCODE_TEAM_ID:-3L8RM3MDLS}"
XCODE_ARCHIVE_SIGNING_STYLE="${XCODE_ARCHIVE_SIGNING_STYLE:-automatic}"
XCODE_ARCHIVE_SIGNING_CERTIFICATE="${XCODE_ARCHIVE_SIGNING_CERTIFICATE:-}"
XCODE_ARCHIVE_PROVISIONING_PROFILE_SPECIFIER="${XCODE_ARCHIVE_PROVISIONING_PROFILE_SPECIFIER:-}"
XCODE_ARCHIVE_ALLOW_PROVISIONING_UPDATES="${XCODE_ARCHIVE_ALLOW_PROVISIONING_UPDATES:-1}"
XCODE_ARCHIVE_TARGET_LEVEL_MANUAL_SIGNING="${XCODE_ARCHIVE_TARGET_LEVEL_MANUAL_SIGNING:-0}"
XCODE_EXPORT_SIGNING_STYLE="${XCODE_EXPORT_SIGNING_STYLE:-${XCODE_SIGNING_STYLE:-automatic}}"
XCODE_EXPORT_SIGNING_CERTIFICATE="${XCODE_EXPORT_SIGNING_CERTIFICATE:-${XCODE_SIGNING_CERTIFICATE:-${SIGNING_IDENTITY:-}}}"
XCODE_EXPORT_PROVISIONING_PROFILE_SPECIFIER="${XCODE_EXPORT_PROVISIONING_PROFILE_SPECIFIER:-${XCODE_PROVISIONING_PROFILE_SPECIFIER:-}}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TIMESTAMP_RETRIES="${TIMESTAMP_RETRIES:-5}"
TIMESTAMP_RETRY_SLEEP="${TIMESTAMP_RETRY_SLEEP:-10}"

# Load .env if exists
if [ -f ".env" ]; then
    echo -e "${YELLOW}📂 Loading .env configuration...${NC}"
    set -a
    source .env
    set +a
fi

# Optional: reduce network dependency during weak connectivity.
XCODEBUILD_PACKAGE_FLAGS=()
if [ "${NO_SPM_UPDATE:-0}" = "1" ]; then
    echo -e "${YELLOW}📦 NO_SPM_UPDATE=1, using resolved package versions only...${NC}"
    XCODEBUILD_PACKAGE_FLAGS+=(
        -disableAutomaticPackageResolution
        -onlyUsePackageVersionsFromResolvedFile
    )
fi

# Get architecture argument
ARCH="${1:-}"

# Ensure release directory exists
mkdir -p "$RELEASE_DIR"

validate_xcode_official_signing_inputs() {
    if [ "$USE_XCODE_OFFICIAL_SIGNING" != "1" ]; then
        return 0
    fi

    if [ "$XCODE_EXPORT_METHOD" = "developer-id" ] && [ -z "$XCODE_EXPORT_PROVISIONING_PROFILE_SPECIFIER" ]; then
        echo -e "${RED}❌ Xcode official signing with method=developer-id requires XCODE_PROVISIONING_PROFILE_SPECIFIER.${NC}"
        echo -e "${RED}   Provide the Developer ID provisioning profile name for bundle id nolon.overloaded.com before packaging.${NC}"
        return 1
    fi
}

validate_xcode_official_signing_inputs

run_codesign_with_timestamp() {
    local target_path="$1"
    shift

    local attempt=1
    while [ "$attempt" -le "$TIMESTAMP_RETRIES" ]; do
        if codesign "$@" --timestamp "$target_path"; then
            return 0
        fi

        if [ "$attempt" -ge "$TIMESTAMP_RETRIES" ]; then
            echo -e "${RED}❌ Failed to sign with secure timestamp: ${target_path}${NC}"
            return 1
        fi

        echo -e "${YELLOW}⚠️  Timestamp service unavailable, retrying in ${TIMESTAMP_RETRY_SLEEP}s (${attempt}/${TIMESTAMP_RETRIES})${NC}"
        sleep "$TIMESTAMP_RETRY_SLEEP"
        attempt=$((attempt + 1))
    done
}

app_requires_embedded_profile() {
    if [ ! -f "$APP_ENTITLEMENTS_PATH" ]; then
        return 1
    fi

    local restricted_keys=(
        "com.apple.developer.aps-environment"
        "com.apple.developer.icloud-container-identifiers"
        "com.apple.developer.icloud-services"
    )

    local key
    for key in "${restricted_keys[@]}"; do
        if plutil -extract "$key" xml1 -o - "$APP_ENTITLEMENTS_PATH" >/dev/null 2>&1; then
            return 0
        fi
    done

    return 1
}

embed_provisioning_profile_if_needed() {
    local app_path="$1"

    if ! app_requires_embedded_profile; then
        return 0
    fi

    if [ -z "$EMBEDDED_PROVISION_PROFILE_PATH" ]; then
        echo -e "${RED}❌ Restricted entitlements detected in ${APP_ENTITLEMENTS_PATH}, but EMBEDDED_PROVISION_PROFILE_PATH is not set.${NC}"
        echo -e "${RED}   CloudKit / Push-enabled macOS apps need a matching provisioning profile embedded in the app bundle, or launchd will reject launch.${NC}"
        return 1
    fi

    if [ ! -f "$EMBEDDED_PROVISION_PROFILE_PATH" ]; then
        echo -e "${RED}❌ EMBEDDED_PROVISION_PROFILE_PATH does not exist: ${EMBEDDED_PROVISION_PROFILE_PATH}${NC}"
        return 1
    fi

    echo -e "${YELLOW}📄 Embedding provisioning profile: ${EMBEDDED_PROVISION_PROFILE_PATH}${NC}"
    cp "$EMBEDDED_PROVISION_PROFILE_PATH" "${app_path}/Contents/embedded.provisionprofile"
}

validate_embedded_profile_if_needed() {
    local app_path="$1"

    if ! app_requires_embedded_profile; then
        return 0
    fi

    if [ ! -f "${app_path}/Contents/embedded.provisionprofile" ]; then
        echo -e "${RED}❌ App is signed with restricted entitlements, but Contents/embedded.provisionprofile is missing.${NC}"
        echo -e "${RED}   This build would pass codesign verification but fail to launch under AMFI.${NC}"
        return 1
    fi
}

append_xcode_signing_build_settings() {
    local settings_ref_name="$1"
    local phase="$2"
    local signing_style
    local signing_certificate
    local provisioning_profile_specifier

    if [ -n "$XCODE_TEAM_ID" ]; then
        eval "${settings_ref_name}+=(\"DEVELOPMENT_TEAM=${XCODE_TEAM_ID}\")"
    fi

    if [ "$phase" = "archive" ]; then
        signing_style="$XCODE_ARCHIVE_SIGNING_STYLE"
        signing_certificate="$XCODE_ARCHIVE_SIGNING_CERTIFICATE"
        provisioning_profile_specifier="$XCODE_ARCHIVE_PROVISIONING_PROFILE_SPECIFIER"
    else
        signing_style="$XCODE_EXPORT_SIGNING_STYLE"
        signing_certificate="$XCODE_EXPORT_SIGNING_CERTIFICATE"
        provisioning_profile_specifier="$XCODE_EXPORT_PROVISIONING_PROFILE_SPECIFIER"
    fi

    if [ "$signing_style" = "manual" ]; then
        eval "${settings_ref_name}+=(\"CODE_SIGN_STYLE=Manual\")"

        if [ -n "$signing_certificate" ]; then
            eval "${settings_ref_name}+=(\"CODE_SIGN_IDENTITY=${signing_certificate}\")"
        fi

        if [ -n "$provisioning_profile_specifier" ]; then
            eval "${settings_ref_name}+=(\"PROVISIONING_PROFILE_SPECIFIER=${provisioning_profile_specifier}\")"
        fi
    fi
}

create_export_options_plist() {
    local plist_path="$1"
    local export_signing_style="$XCODE_EXPORT_SIGNING_STYLE"

    if [ -n "$XCODE_EXPORT_PROVISIONING_PROFILE_SPECIFIER" ]; then
        export_signing_style="manual"
    fi

    cat > "$plist_path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${XCODE_EXPORT_METHOD}</string>
    <key>signingStyle</key>
    <string>${export_signing_style}</string>
    <key>teamID</key>
    <string>${XCODE_TEAM_ID}</string>
EOF

    if [ -n "$XCODE_EXPORT_SIGNING_CERTIFICATE" ]; then
        cat >> "$plist_path" <<EOF
    <key>signingCertificate</key>
    <string>${XCODE_EXPORT_SIGNING_CERTIFICATE}</string>
EOF
    fi

    if [ -n "$XCODE_EXPORT_PROVISIONING_PROFILE_SPECIFIER" ]; then
        cat >> "$plist_path" <<EOF
    <key>provisioningProfiles</key>
    <dict>
        <key>nolon.overloaded.com</key>
        <string>${XCODE_EXPORT_PROVISIONING_PROFILE_SPECIFIER}</string>
    </dict>
EOF
    fi

    cat >> "$plist_path" <<EOF
</dict>
</plist>
EOF
}

prepare_xcode_project_archive_signing_override() {
    local backup_ref_name="$1"
    local project_pbxproj="${PROJECT}/project.pbxproj"

    if [ "$XCODE_ARCHIVE_TARGET_LEVEL_MANUAL_SIGNING" != "1" ]; then
        return 0
    fi

    if [ -z "$XCODE_ARCHIVE_SIGNING_CERTIFICATE" ] || [ -z "$XCODE_ARCHIVE_PROVISIONING_PROFILE_SPECIFIER" ]; then
        echo -e "${RED}❌ XCODE_ARCHIVE_TARGET_LEVEL_MANUAL_SIGNING=1 requires XCODE_ARCHIVE_SIGNING_CERTIFICATE and XCODE_ARCHIVE_PROVISIONING_PROFILE_SPECIFIER.${NC}"
        return 1
    fi

    local project_backup
    project_backup="$(mktemp "${project_pbxproj}.archive-signing.XXXXXX")"
    cp "$project_pbxproj" "$project_backup"
    eval "${backup_ref_name}=\"${project_backup}\""

    python3 - "$project_pbxproj" "$XCODE_TEAM_ID" "$XCODE_ARCHIVE_SIGNING_CERTIFICATE" "$XCODE_ARCHIVE_PROVISIONING_PROFILE_SPECIFIER" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
team = sys.argv[2]
identity = sys.argv[3]
profile = sys.argv[4]
text = path.read_text()

pattern = re.compile(
    r'(CD2B1A9F2F1F624A00DF4A2B /\* Release \*/ = \{\s*isa = XCBuildConfiguration;\s*buildSettings = \{\n)(.*?)(\s*\};\s*name = Release;\s*\};)',
    re.S,
)
match = pattern.search(text)
if not match:
    raise SystemExit("Could not locate nolon Release build configuration block in project.pbxproj")

settings = match.group(2)
settings = re.sub(r'\n\s*CODE_SIGN_STYLE = [^;]+;', '\n\t\t\t\tCODE_SIGN_STYLE = Manual;', settings)
settings = re.sub(r'\n\s*DEVELOPMENT_TEAM = [^;]+;', f'\n\t\t\t\tDEVELOPMENT_TEAM = {team};', settings)
settings = re.sub(r'\n\s*CODE_SIGN_IDENTITY = [^;]+;', '', settings)
settings = re.sub(r'\n\s*PROVISIONING_PROFILE_SPECIFIER = [^;]+;', '', settings)

anchor = f'\n\t\t\t\tDEVELOPMENT_TEAM = {team};'
insertion = (
    anchor
    + f'\n\t\t\t\tCODE_SIGN_IDENTITY = "{identity}";'
    + f'\n\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{profile}";'
)
if anchor not in settings:
    raise SystemExit("Could not find DEVELOPMENT_TEAM anchor in nolon Release build settings")
settings = settings.replace(anchor, insertion, 1)

updated = text[:match.start()] + match.group(1) + settings + match.group(3) + text[match.end():]
path.write_text(updated)
PY
}

restore_xcode_project_archive_signing_override() {
    local project_backup="$1"
    local project_pbxproj="${PROJECT}/project.pbxproj"

    if [ -n "$project_backup" ] && [ -f "$project_backup" ]; then
        mv "$project_backup" "$project_pbxproj"
    fi
}

# Function to sign the app
sign_app() {
    local app_path="$1"
    
    if [ -z "$SIGNING_IDENTITY" ]; then
        echo -e "${YELLOW}⚠️  SIGNING_IDENTITY not set, skipping code signing${NC}"
        return 0
    fi

    embed_provisioning_profile_if_needed "$app_path" || return 1

    # Sign embedded git binaries that live under Resources and are not always covered by --deep.
    local git_bundle_path="${app_path}/Contents/Resources/SwiftGit_SwiftGitResourcesUniversal.bundle/Contents/Resources/git-instance.bundle"
    if [ -d "$git_bundle_path" ]; then
        echo -e "${YELLOW}🔐 Signing embedded git binaries...${NC}"
        while IFS= read -r -d '' file_path; do
            if file "$file_path" | grep -q "Mach-O"; then
                run_codesign_with_timestamp "$file_path" \
                    --force \
                    --options runtime \
                    --sign "$SIGNING_IDENTITY"
            fi
        done < <(find "$git_bundle_path" -type f -print0)
    fi
    
    echo -e "${YELLOW}🔏 Signing app with: ${SIGNING_IDENTITY}${NC}"
    local codesign_args=(
        --force
        --deep
        --options runtime
        --sign "$SIGNING_IDENTITY"
    )

    if [ -f "$APP_ENTITLEMENTS_PATH" ]; then
        echo -e "${YELLOW}☁️  Applying app entitlements: ${APP_ENTITLEMENTS_PATH}${NC}"
        codesign_args+=(--entitlements "$APP_ENTITLEMENTS_PATH")
    else
        echo -e "${YELLOW}⚠️  App entitlements file not found, signing without explicit entitlements${NC}"
    fi

    run_codesign_with_timestamp "$app_path" "${codesign_args[@]}"
    validate_embedded_profile_if_needed "$app_path" || return 1
    
    echo -e "${GREEN}✅ App signed${NC}"
}

# Function to notarize the DMG
notarize_dmg() {
    local dmg_path="$1"
    
    # Check if we have notarization credentials
    if [ -n "$NOTARY_PROFILE" ]; then
        echo -e "${YELLOW}📤 Notarizing DMG with profile: ${NOTARY_PROFILE}${NC}"
        xcrun notarytool submit "$dmg_path" \
            --keychain-profile "$NOTARY_PROFILE" \
            --wait
    elif [ -n "$APPLE_ID" ] && [ -n "$APPLE_APP_PASSWORD" ] && [ -n "$TEAM_ID" ]; then
        echo -e "${YELLOW}📤 Notarizing DMG...${NC}"
        xcrun notarytool submit "$dmg_path" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_APP_PASSWORD" \
            --team-id "$TEAM_ID" \
            --wait
    else
        echo -e "${YELLOW}⚠️  Notarization credentials not set, skipping notarization${NC}"
        return 0
    fi
    
    # Staple the notarization ticket
    echo -e "${YELLOW}📎 Stapling notarization ticket...${NC}"
    xcrun stapler staple "$dmg_path"
    
    echo -e "${GREEN}✅ DMG notarized and stapled${NC}"
}

build_for_arch() {
    local arch="$1"
    local dmg_name="${RELEASE_DIR}/${APP_NAME}-${arch}.dmg"
    local build_suffix="${arch}"
    local app_path
    
    echo -e "${YELLOW}🔨 Building ${APP_NAME} for ${arch}...${NC}"

    if [ "$USE_XCODE_OFFICIAL_SIGNING" = "1" ]; then
        local archive_path="${BUILD_DIR}-${build_suffix}/${APP_NAME}-${arch}.xcarchive"
        local export_path="${BUILD_DIR}-${build_suffix}/export-${arch}"
        local export_options_plist="${BUILD_DIR}-${build_suffix}/export-options-${arch}.plist"
        local project_backup_path=""
        local archive_args=(
            "${XCODEBUILD_PACKAGE_FLAGS[@]}"
            -project "$PROJECT"
            -scheme "$SCHEME"
            -configuration Release
            -archivePath "$archive_path"
            -destination "generic/platform=macOS"
            "ARCHS=${arch}"
            clean
            archive
        )

        if [ "$XCODE_ARCHIVE_TARGET_LEVEL_MANUAL_SIGNING" != "1" ] && [ "$XCODE_ARCHIVE_SIGNING_STYLE" = "automatic" ] && [ "$XCODE_ARCHIVE_ALLOW_PROVISIONING_UPDATES" = "1" ]; then
            archive_args+=(-allowProvisioningUpdates)
        fi

        prepare_xcode_project_archive_signing_override project_backup_path || return 1

        append_xcode_signing_build_settings archive_args archive

        echo -e "${YELLOW}🧾 Using Xcode official signing chain (archive/export).${NC}"
        trap 'restore_xcode_project_archive_signing_override "$project_backup_path"' RETURN
        xcodebuild "${archive_args[@]}"
        trap - RETURN
        restore_xcode_project_archive_signing_override "$project_backup_path"

        create_export_options_plist "$export_options_plist"

        xcodebuild \
            -exportArchive \
            -archivePath "$archive_path" \
            -exportPath "$export_path" \
            -exportOptionsPlist "$export_options_plist"

        app_path="${export_path}/${APP_NAME}.app"
    else
        xcodebuild "${XCODEBUILD_PACKAGE_FLAGS[@]}" \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration Release \
            -derivedDataPath "${BUILD_DIR}-${build_suffix}" \
            -arch "$arch" \
            clean build \
            CODE_SIGNING_ALLOWED=NO

        app_path="${BUILD_DIR}-${build_suffix}/Build/Products/Release/${APP_NAME}.app"

        echo -e "${GREEN}✅ Build succeeded for ${arch}${NC}"
        sign_app "$app_path"
    fi

    if [ ! -d "$app_path" ]; then
        echo -e "${RED}❌ Build failed: ${app_path} not found${NC}"
        return 1
    fi

    validate_embedded_profile_if_needed "$app_path" || return 1

    echo -e "${GREEN}✅ Build succeeded for ${arch}${NC}"
    
    # Create DMG
    create_dmg_for_app "$app_path" "$dmg_name" "$arch"
    
    # Notarize the DMG
    notarize_dmg "$dmg_name"
}

create_dmg_for_app() {
    local app_path="$1"
    local dmg_name="$2"
    local arch="$3"

    create_dmg_with_hdiutil() {
        local app_path="$1"
        local dmg_name="$2"
        local arch="$3"

        echo -e "${YELLOW}📦 Creating DMG with hdiutil for ${arch}...${NC}"

        # Create staging directory
        STAGING_DIR="${BUILD_DIR}/dmg-staging-${arch}"
        rm -rf "$STAGING_DIR"
        mkdir -p "$STAGING_DIR"

        # Copy app to staging
        cp -R "$app_path" "$STAGING_DIR/"

        # Create Applications symlink
        ln -s /Applications "$STAGING_DIR/Applications"

        # Remove existing DMG
        rm -f "$dmg_name"

        # Create DMG
        hdiutil create \
            -volname "$APP_NAME" \
            -srcfolder "$STAGING_DIR" \
            -ov \
            -format UDZO \
            "$dmg_name"

        # Cleanup
        rm -rf "$STAGING_DIR"
    }
    
    # Check if create-dmg is installed
    if command -v create-dmg &> /dev/null; then
        echo -e "${YELLOW}📦 Creating DMG for ${arch}...${NC}"
        
        # Remove existing DMG and temp files
        rm -f "$dmg_name"
        rm -f "${RELEASE_DIR}/rw.*.dmg" 2>/dev/null || true
        
        # Close any open Finder windows for the volume
        osascript -e 'tell application "Finder" to close every window' 2>/dev/null || true
        
        create-dmg \
            --volname "${APP_NAME}" \
            --window-pos 200 120 \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "${APP_NAME}.app" 150 185 \
            --app-drop-link 450 185 \
            --hide-extension "${APP_NAME}.app" \
            --no-internet-enable \
            "$dmg_name" \
            "$app_path" || true

        if [ ! -f "$dmg_name" ]; then
            echo -e "${YELLOW}⚠️  create-dmg had issues, trying fallback...${NC}"
            rm -f "${RELEASE_DIR}/rw.*.dmg" 2>/dev/null || true
            create_dmg_with_hdiutil "$app_path" "$dmg_name" "$arch"
        fi
    else
        create_dmg_with_hdiutil "$app_path" "$dmg_name" "$arch"
    fi
    
    echo -e "${GREEN}✅ DMG created: ${dmg_name}${NC}"
    ls -lh "$dmg_name"
}

# Main logic
case "$ARCH" in
    arm64)
        build_for_arch "arm64"
        ;;
    x86_64)
        build_for_arch "x86_64"
        ;;
    all)
        build_for_arch "arm64"
        echo ""
        build_for_arch "x86_64"
        echo ""
        echo -e "${GREEN}✅ All builds complete!${NC}"
        echo -e "${GREEN}📍 Outputs:${NC}"
        ls -lh "${RELEASE_DIR}/"*.dmg
        ;;
    "")
        # Default: build for current architecture only
        DMG_NAME="${RELEASE_DIR}/${APP_NAME}.dmg"
        echo -e "${YELLOW}🔨 Building ${APP_NAME} for Release...${NC}"
        
        xcodebuild "${XCODEBUILD_PACKAGE_FLAGS[@]}" \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration Release \
            -derivedDataPath "$BUILD_DIR" \
            clean build \
            CODE_SIGNING_ALLOWED=NO
        
        APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"
        
        if [ ! -d "$APP_PATH" ]; then
            echo -e "${RED}❌ Build failed: ${APP_PATH} not found${NC}"
            exit 1
        fi
        
        echo -e "${GREEN}✅ Build succeeded${NC}"
        create_dmg_for_app "$APP_PATH" "$DMG_NAME" "current"
        ;;
    *)
        echo -e "${RED}❌ Unknown architecture: ${ARCH}${NC}"
        echo "Usage: $0 [arm64|x86_64|all]"
        exit 1
        ;;
esac
