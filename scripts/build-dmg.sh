#!/bin/bash
# Build and package nolon.app as DMG
# Usage: ./scripts/build-dmg.sh

set -e

# Configuration
APP_NAME="nolon"
SCHEME="nolon"
PROJECT="nolon.xcodeproj"
BUILD_DIR="build"
RELEASE_DIR="release"
DMG_NAME="${RELEASE_DIR}/${APP_NAME}.dmg"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔨 Building ${APP_NAME} for Release...${NC}"

# Ensure release directory exists
mkdir -p "$RELEASE_DIR"

# Clean and build
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

# Check if create-dmg is installed
if command -v create-dmg &> /dev/null; then
    echo -e "${YELLOW}📦 Creating DMG with create-dmg...${NC}"
    
    # Remove existing DMG and temp files
    rm -f "$DMG_NAME"
    rm -f rw.*.dmg 2>/dev/null || true
    
    # Close any open Finder windows for the volume
    osascript -e 'tell application "Finder" to close every window' 2>/dev/null || true
    
    create-dmg \
        --volname "$APP_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 150 185 \
        --app-drop-link 450 185 \
        --hide-extension "${APP_NAME}.app" \
        --no-internet-enable \
        "$DMG_NAME" \
        "$APP_PATH" || {
            echo -e "${YELLOW}⚠️  create-dmg had issues, trying fallback...${NC}"
            # Cleanup and try hdiutil fallback
            rm -f rw.*.dmg 2>/dev/null || true
            hdiutil detach /dev/disk* 2>/dev/null || true
        }
else
    echo -e "${YELLOW}📦 Creating DMG with hdiutil...${NC}"
    echo -e "${YELLOW}💡 Tip: Install create-dmg for prettier DMGs: brew install create-dmg${NC}"
    
    # Create staging directory
    STAGING_DIR="$BUILD_DIR/dmg-staging"
    rm -rf "$STAGING_DIR"
    mkdir -p "$STAGING_DIR"
    
    # Copy app to staging
    cp -R "$APP_PATH" "$STAGING_DIR/"
    
    # Create Applications symlink
    ln -s /Applications "$STAGING_DIR/Applications"
    
    # Remove existing DMG
    rm -f "$DMG_NAME"
    
    # Create DMG
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov \
        -format UDZO \
        "$DMG_NAME"
    
    # Cleanup
    rm -rf "$STAGING_DIR"
fi

echo -e "${GREEN}✅ DMG created: ${DMG_NAME}${NC}"
echo -e "${GREEN}📍 Location: $(pwd)/${DMG_NAME}${NC}"

# Optional: Show DMG info
echo ""
echo -e "${YELLOW}📊 DMG Info:${NC}"
ls -lh "$DMG_NAME"
