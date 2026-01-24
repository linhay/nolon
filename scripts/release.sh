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

# ------------------------------------------------------------------------------
# Sparkle Integration
# ------------------------------------------------------------------------------

SPARKLE_VERSION="2.6.4"
SPARKLE_DIR="temp_sparkle"
SPARKLE_BIN="${SPARKLE_DIR}/bin"

# Download Sparkle tools if missing
if [ ! -d "$SPARKLE_DIR" ]; then
    echo -e "${YELLOW}⬇️  Downloading Sparkle ${SPARKLE_VERSION}...${NC}"
    mkdir -p "$SPARKLE_DIR"
    curl -L -s "https://github.com/sparkle-project/Sparkle/releases/download/${SPARKLE_VERSION}/Sparkle-${SPARKLE_VERSION}.tar.xz" | tar -xJ -C "$SPARKLE_DIR"
fi

# Sign DMGs
echo -e "${YELLOW}✍️  Signing updates with Sparkle...${NC}"
SIGNATURE_ARM64=$("$SPARKLE_BIN/sign_update" "$DMG_ARM64")
SIGNATURE_X86_64=$("$SPARKLE_BIN/sign_update" "$DMG_X86_64")

# Helper to extract EdDSA signature
get_signature() {
    echo "$1" | grep "sparkle:edSignature" | sed 's/.*sparkle:edSignature="//;s/".*//'
}

ED_SIG_ARM64=$(get_signature "$SIGNATURE_ARM64")
ED_SIG_X86_64=$(get_signature "$SIGNATURE_X86_64")

# Update Appcast
APPCAST_FILE="docs/appcast.xml"
APPCAST_URL="https://linhay.github.io/nolon/appcast.xml"
DOWNLOAD_BASE_URL="https://github.com/linhay/nolon/releases/download/${TAG}"
DATE_RFC2822=$(date "+%a, %d %b %Y %H:%M:%S %z")

# Ensure docs directory exists
mkdir -p docs

# If appcast doesn't exist, create it
if [ ! -f "$APPCAST_FILE" ]; then
    cat > "$APPCAST_FILE" <<EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>Nolon Changelog</title>
        <link>${APPCAST_URL}</link>
        <description>Most recent changes with links to updates.</description>
        <language>en</language>
    </channel>
</rss>
EOF
fi

# Generate the new item entry
# Note: Sparkle supports multiple enclosures in one item for different architectures (sparkle:os="macos" and sparkle:cpu)
# But here we add two Enclosures to one Item or use two Items?
# Sparkle 2.x best practice: One item per version, multiple enclosures.

SIZE_ARM64=$(stat -f%z "$DMG_ARM64")
SIZE_X86_64=$(stat -f%z "$DMG_X86_64")

NEW_ITEM="
        <item>
            <title>${VERSION}</title>
            <pubDate>${DATE_RFC2822}</pubDate>
            <sparkle:version>${VERSION}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <link>${DOWNLOAD_BASE_URL}/nolon-arm64.dmg</link>
            <description><![CDATA[${RELEASE_NOTES}]]></description>
            <enclosure url=\"${DOWNLOAD_BASE_URL}/nolon-arm64.dmg\"
                       sparkle:version=\"${VERSION}\"
                       sparkle:shortVersionString=\"${VERSION}\"
                       sparkle:edSignature=\"${ED_SIG_ARM64}\"
                       length=\"${SIZE_ARM64}\"
                       type=\"application/x-apple-diskimage\"
                       sparkle:os=\"macos\" />
            <enclosure url=\"${DOWNLOAD_BASE_URL}/nolon-x86_64.dmg\"
                       sparkle:version=\"${VERSION}\"
                       sparkle:shortVersionString=\"${VERSION}\"
                       sparkle:edSignature=\"${ED_SIG_X86_64}\"
                       length=\"${SIZE_X86_64}\"
                       type=\"application/x-apple-diskimage\"
                       sparkle:os=\"macos\" />
        </item>"

# Insert the new item before the closing </channel> tag
# We use a temporary file to construct the new XML
# Note: simple sed might be deleting newlines, so we use perl or awk or just simple sed with caution.
# Here's a safe sed approach for inserting before a match.

sed -i '' "/<\/channel>/i\\
$NEW_ITEM
" "$APPCAST_FILE"

echo -e "${GREEN}✅ Appcast updated at ${APPCAST_FILE}${NC}"

# Commit and Push Appcast
echo -e "${YELLOW}GIT committing appcast...${NC}"
git add "$APPCAST_FILE"
git commit -m "Update appcast for ${VERSION}"
git push origin HEAD

# ------------------------------------------------------------------------------
# End Sparkle Integration
# ------------------------------------------------------------------------------

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

# Enable GitHub Pages if not already enabled
echo -e "${YELLOW}⚙️  Check GitHub Pages...${NC}"
gh api repos/:owner/:repo/pages -X POST -f source='{"branch":"main","path":"/docs"}' --silent || true
echo -e "${GREEN}✅ GitHub Pages configured!${NC}"
