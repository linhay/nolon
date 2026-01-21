#!/bin/bash
# Create a GitHub release and upload DMG assets for both architectures
# Usage: ./scripts/release.sh [version]
# Example: ./scripts/release.sh 1.0.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
APP_NAME="nolon"
RELEASE_DIR="release"
DMG_ARM64="${RELEASE_DIR}/${APP_NAME}-arm64.dmg"
DMG_X86_64="${RELEASE_DIR}/${APP_NAME}-x86_64.dmg"

# Get version from argument or prompt
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo -e "${YELLOW}Enter version (e.g., 1.0.0):${NC}"
    read -r VERSION
fi

if [ -z "$VERSION" ]; then
    echo -e "${RED}❌ Version is required${NC}"
    exit 1
fi

TAG="v${VERSION}"

# Check if gh is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed${NC}"
    echo -e "${YELLOW}Install with: brew install gh${NC}"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Not authenticated with GitHub${NC}"
    echo -e "${YELLOW}Run: gh auth login${NC}"
    exit 1
fi

# Update version in Xcode project
echo -e "${YELLOW}📝 Updating version to ${VERSION}...${NC}"
PROJECT_FILE="nolon.xcodeproj/project.pbxproj"

# Update MARKETING_VERSION
sed -i '' "s/MARKETING_VERSION = [^;]*;/MARKETING_VERSION = ${VERSION};/g" "$PROJECT_FILE"

# Update CURRENT_PROJECT_VERSION (build number)
BUILD_NUMBER=$(date +%Y%m%d%H%M)
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*;/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};/g" "$PROJECT_FILE"

echo -e "${GREEN}✅ Version updated: ${VERSION} (build ${BUILD_NUMBER})${NC}"

# Build DMGs for both architectures
echo -e "${YELLOW}📦 Building DMGs for all architectures...${NC}"
./scripts/build-dmg.sh all

# Verify DMGs exist
if [ ! -f "$DMG_ARM64" ]; then
    echo -e "${RED}❌ arm64 DMG not found: ${DMG_ARM64}${NC}"
    exit 1
fi

if [ ! -f "$DMG_X86_64" ]; then
    echo -e "${RED}❌ x86_64 DMG not found: ${DMG_X86_64}${NC}"
    exit 1
fi

echo -e "${YELLOW}🚀 Creating release ${TAG}...${NC}"

# Generate release notes
RELEASE_NOTES="## ${APP_NAME} ${VERSION}

### Downloads

| Platform | Architecture | Download |
|----------|--------------|----------|
| macOS | Apple Silicon (M1/M2/M3) | \`${APP_NAME}-arm64.dmg\` |
| macOS | Intel | \`${APP_NAME}-x86_64.dmg\` |

### Installation
1. Download the appropriate DMG for your Mac
   - **Apple Silicon** (M1, M2, M3 chips): \`${APP_NAME}-arm64.dmg\`
   - **Intel** (older Macs): \`${APP_NAME}-x86_64.dmg\`
2. Open the DMG and drag ${APP_NAME} to Applications
3. Launch ${APP_NAME} from Applications

### System Requirements
- macOS 14.0 or later

---
*Built on $(date '+%Y-%m-%d')*"

# Create release and upload both DMGs
gh release create "$TAG" \
    --title "${APP_NAME} ${VERSION}" \
    --notes "$RELEASE_NOTES" \
    "$DMG_ARM64" \
    "$DMG_X86_64"

echo -e "${GREEN}✅ Release ${TAG} created successfully!${NC}"
echo -e "${GREEN}📍 View at: $(gh repo view --json url -q .url)/releases/tag/${TAG}${NC}"
