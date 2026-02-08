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
SCHEME="nolon"
PROJECT="nolon.xcodeproj"
RELEASE_DIR="release"
BUILD_DIR="${RELEASE_DIR}/build"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load .env if exists
if [ -f ".env" ]; then
    echo -e "${YELLOW}📂 Loading .env configuration...${NC}"
    set -a
    source .env
    set +a
fi

# Get architecture argument
ARCH="${1:-}"

# Ensure release directory exists
mkdir -p "$RELEASE_DIR"

# Function to sign the app
sign_app() {
    local app_path="$1"
    
    if [ -z "$SIGNING_IDENTITY" ]; then
        echo -e "${YELLOW}⚠️  SIGNING_IDENTITY not set, skipping code signing${NC}"
        return 0
    fi

    # Sign embedded git binaries that live under Resources and are not always covered by --deep.
    local git_bundle_path="${app_path}/Contents/Resources/SwiftGit_SwiftGitResourcesUniversal.bundle/Contents/Resources/git-instance.bundle"
    if [ -d "$git_bundle_path" ]; then
        echo -e "${YELLOW}🔐 Signing embedded git binaries...${NC}"
        while IFS= read -r -d '' file_path; do
            if file "$file_path" | grep -q "Mach-O"; then
                codesign --force --options runtime --timestamp \
                    --sign "$SIGNING_IDENTITY" \
                    "$file_path"
            fi
        done < <(find "$git_bundle_path" -type f -print0)
    fi
    
    echo -e "${YELLOW}🔏 Signing app with: ${SIGNING_IDENTITY}${NC}"
    codesign --force --deep --options runtime --timestamp \
        --sign "$SIGNING_IDENTITY" \
        "$app_path"
    
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
    
    echo -e "${YELLOW}🔨 Building ${APP_NAME} for ${arch}...${NC}"
    
    # Clean and build for specific architecture
    xcodebuild -project "$PROJECT" \
        -scheme "$SCHEME" \
        -configuration Release \
        -derivedDataPath "${BUILD_DIR}-${build_suffix}" \
        -arch "$arch" \
        clean build
    
    APP_PATH="${BUILD_DIR}-${build_suffix}/Build/Products/Release/${APP_NAME}.app"
    
    if [ ! -d "$APP_PATH" ]; then
        echo -e "${RED}❌ Build failed: ${APP_PATH} not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Build succeeded for ${arch}${NC}"
    
    # Sign the app
    sign_app "$APP_PATH"
    
    # Create DMG
    create_dmg_for_app "$APP_PATH" "$dmg_name" "$arch"
    
    # Notarize the DMG
    notarize_dmg "$dmg_name"
}

create_dmg_for_app() {
    local app_path="$1"
    local dmg_name="$2"
    local arch="$3"
    
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
            "$app_path" || {
                echo -e "${YELLOW}⚠️  create-dmg had issues, trying fallback...${NC}"
                rm -f "${RELEASE_DIR}/rw.*.dmg" 2>/dev/null || true
            }
    else
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
        
        xcodebuild -project "$PROJECT" \
            -scheme "$SCHEME" \
            -configuration Release \
            -derivedDataPath "$BUILD_DIR" \
            clean build
        
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
