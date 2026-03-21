#!/bin/bash
# Create a GitHub release and upload DMG assets for both architectures.
#
# This script is designed to be resumable: it creates/updates the GitHub Release first,
# then uploads assets one-by-one with retries, and finally publishes the release.
#
# Usage:
#   ./scripts/release.sh [version]
#   ./scripts/release.sh [version] [changelog_file]
#
# Optional env:
#   SKIP_BUILD=1            Skip ./scripts/build-dmg.sh all
#   UPLOAD_RETRIES=5        Retry count for each asset upload
#   UPLOAD_SLEEP_BASE=5     Base sleep seconds between retries (exponential-ish)
#   UPLOAD_TIMEOUT_SECONDS=1800  Per-asset upload timeout in seconds (30 min default)
#   PAGES_WAIT_TIMEOUT_SECONDS=600  Max seconds to wait for Pages/appcast propagation
#   PAGES_WAIT_INTERVAL_SECONDS=5   Poll interval when waiting for Pages/appcast
#   PAGES_WAIT_STRICT=1             If 1, stop before publish when appcast is not live
#   APPCAST_URL=https://linhay.github.io/nolon/appcast.xml

set -euo pipefail

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
CHANGELOG_FILE="${2:-}"

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

# Ensure working tree is clean before starting.
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "${RED}❌ Working tree is not clean.${NC}"
    echo -e "${YELLOW}Commit or stash changes first, then re-run:${NC} ./scripts/release.sh ${VERSION}${NC}"
    git status --porcelain=v1 || true
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
if [ "${SKIP_BUILD:-0}" = "1" ]; then
    echo -e "${YELLOW}⏭️  SKIP_BUILD=1, skip building DMGs.${NC}"
else
    echo -e "${YELLOW}📦 Building DMGs for all architectures...${NC}"
    ./scripts/build-dmg.sh all
fi

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
sign_update_with_available_key() {
    local update_path="$1"

    if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
        echo -e "${YELLOW}🔐 Using SPARKLE_PRIVATE_KEY from environment for signing...${NC}"
        printf '%s' "${SPARKLE_PRIVATE_KEY}" | "$SPARKLE_BIN/sign_update" --ed-key-file - "$update_path"
        return 0
    fi

    local keychain_account="${SPARKLE_KEYCHAIN_ACCOUNT:-ed25519}"
    echo -e "${YELLOW}🔐 Using keychain account '${keychain_account}' for signing...${NC}"
    "$SPARKLE_BIN/sign_update" --account "${keychain_account}" "$update_path"
}

SIGNATURE_ARM64=$(sign_update_with_available_key "$DMG_ARM64")
SIGNATURE_X86_64=$(sign_update_with_available_key "$DMG_X86_64")

# Helper to extract EdDSA signature
get_signature() {
    echo "$1" | grep "sparkle:edSignature" | sed 's/.*sparkle:edSignature="//;s/".*//'
}

ED_SIG_ARM64=$(get_signature "$SIGNATURE_ARM64")
ED_SIG_X86_64=$(get_signature "$SIGNATURE_X86_64")

# ------------------------------------------------------------------------------
# Generate release notes
# ------------------------------------------------------------------------------

echo -e "${YELLOW}📝 Generating release notes...${NC}"

PREV_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$PREV_TAG" ]; then
    CHANGELOG="- Initial release"
else
    if [ -n "$CHANGELOG_FILE" ] && [ -f "$CHANGELOG_FILE" ]; then
        echo -e "${YELLOW}📄 Using custom changelog from ${CHANGELOG_FILE}...${NC}"
        CHANGELOG=$(cat "$CHANGELOG_FILE")
    elif [ -f "docs/RELEASE_NOTES_${VERSION}.md" ]; then
        echo -e "${YELLOW}📄 Using release notes from docs/RELEASE_NOTES_${VERSION}.md...${NC}"
        CHANGELOG=$(cat "docs/RELEASE_NOTES_${VERSION}.md")
    else
        echo -e "Comparing against previous tag: ${PREV_TAG}"
        CHANGELOG=$(git log --pretty=format:"- %s" "${PREV_TAG}..HEAD")
    fi
fi

# If CHANGELOG contains a title starting with '## ', don't add another one
if [[ "$CHANGELOG" == "## "* ]]; then
    RELEASE_NOTES="${CHANGELOG}"
else
    RELEASE_NOTES="## ${APP_NAME} ${VERSION}

### Changes
${CHANGELOG}"
fi

# Add Downloads and Installation info
RELEASE_NOTES="${RELEASE_NOTES}

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

# Update Appcast
APPCAST_FILE="docs/appcast.xml"
APPCAST_FILE_ROOT="appcast.xml"
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
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <link>${DOWNLOAD_BASE_URL}/nolon-arm64.dmg</link>
            <description><![CDATA[<div style=\"white-space: pre-wrap; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;\">${RELEASE_NOTES}</div>]]></description>
            <enclosure url=\"${DOWNLOAD_BASE_URL}/nolon-arm64.dmg\"
                       sparkle:version=\"${BUILD_NUMBER}\"
                       sparkle:shortVersionString=\"${VERSION}\"
                       sparkle:edSignature=\"${ED_SIG_ARM64}\"
                       length=\"${SIZE_ARM64}\"
                       type=\"application/x-apple-diskimage\"
                       sparkle:os=\"macos\"
                       xml:lang=\"en\" />
            <enclosure url=\"${DOWNLOAD_BASE_URL}/nolon-x86_64.dmg\"
                       sparkle:version=\"${BUILD_NUMBER}\"
                       sparkle:shortVersionString=\"${VERSION}\"
                       sparkle:edSignature=\"${ED_SIG_X86_64}\"
                       length=\"${SIZE_X86_64}\"
                       type=\"application/x-apple-diskimage\"
                       sparkle:os=\"macos\"
                       xml:lang=\"en\" />
        </item>"

# Insert the new item before the closing </channel> tag
# We use a temporary file to construct the new XML
# Note: simple sed might be deleting newlines, so we use perl or awk or just simple sed with caution.
# Here's a safe sed approach for inserting before a match.

# Use Python to insert the XML item reliably
cat > new_item.xml <<EOF
$NEW_ITEM
EOF

python3 -c "
import sys

with open('$APPCAST_FILE', 'r') as f:
    content = f.read()

with open('new_item.xml', 'r') as f:
    new_item = f.read()

# Insert before </channel>
if '</channel>' in content:
    new_content = content.replace('</channel>', new_item + '\n    </channel>')
    with open('$APPCAST_FILE', 'w') as f:
        f.write(new_content)
else:
    print('Error: Could not find </channel> tag in appcast.xml')
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to update appcast.xml${NC}"
    rm new_item.xml
    exit 1
fi

rm new_item.xml

echo -e "${GREEN}✅ Appcast updated at ${APPCAST_FILE}${NC}"

# Mirror appcast at repository root for Pages configurations that publish from "/"
cp "$APPCAST_FILE" "$APPCAST_FILE_ROOT"
echo -e "${GREEN}✅ Appcast mirrored to ${APPCAST_FILE_ROOT}${NC}"

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

if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
    echo -e "${RED}❌ Tag already exists: ${TAG}${NC}"
    exit 1
fi

echo -e "${YELLOW}GIT committing version + appcast...${NC}"
git add "$PROJECT_FILE" "$APPCAST_FILE" "$APPCAST_FILE_ROOT"

if [ -f "docs/RELEASE_NOTES_${VERSION}.md" ]; then
    git add "docs/RELEASE_NOTES_${VERSION}.md"
fi

git commit -m "chore(release): ${TAG}"
git tag -a "${TAG}" -m "${APP_NAME} ${VERSION}"
git push origin HEAD
git push origin "${TAG}"

echo -e "${YELLOW}🚀 Preparing GitHub release ${TAG}...${NC}"

RELEASE_TITLE="${APP_NAME} ${VERSION}"

# Create or update the Release (draft) first; uploads happen separately to avoid "stuck" large uploads.
if gh release view "$TAG" >/dev/null 2>&1; then
    echo -e "${YELLOW}🧩 Release exists; updating title/notes and keeping draft for uploads...${NC}"
    gh release edit "$TAG" \
        --title "${RELEASE_TITLE}" \
        --notes "$RELEASE_NOTES" \
        --draft
else
    echo -e "${YELLOW}🆕 Creating draft release ${TAG} (upload assets next)...${NC}"
    gh release create "$TAG" \
        --title "${RELEASE_TITLE}" \
        --notes "$RELEASE_NOTES" \
        --draft
fi

UPLOAD_RETRIES="${UPLOAD_RETRIES:-5}"
UPLOAD_SLEEP_BASE="${UPLOAD_SLEEP_BASE:-5}"
UPLOAD_TIMEOUT_SECONDS="${UPLOAD_TIMEOUT_SECONDS:-1800}"

UPLOAD_TIMEOUT_CMD=()
if command -v gtimeout >/dev/null 2>&1; then
    UPLOAD_TIMEOUT_CMD=(gtimeout "${UPLOAD_TIMEOUT_SECONDS}")
elif command -v timeout >/dev/null 2>&1; then
    UPLOAD_TIMEOUT_CMD=(timeout "${UPLOAD_TIMEOUT_SECONDS}")
fi

upload_asset() {
    local file="$1"
    local attempt=1
    while true; do
        echo -e "${YELLOW}⬆️  Uploading $(basename "$file") (attempt ${attempt}/${UPLOAD_RETRIES})...${NC}"
        local upload_status=0
        if [ "${#UPLOAD_TIMEOUT_CMD[@]}" -gt 0 ]; then
            if "${UPLOAD_TIMEOUT_CMD[@]}" gh release upload "$TAG" "$file" --clobber; then
                upload_status=0
            else
                upload_status=$?
            fi
        else
            if gh release upload "$TAG" "$file" --clobber; then
                upload_status=0
            else
                upload_status=$?
            fi
        fi

        if [ "$upload_status" -eq 0 ]; then
            echo -e "${GREEN}✅ Uploaded $(basename "$file")${NC}"
            return 0
        fi

        if [ "$upload_status" -eq 124 ]; then
            echo -e "${YELLOW}⏱️  Upload timed out after ${UPLOAD_TIMEOUT_SECONDS}s.${NC}"
        fi

        if [ "$attempt" -ge "$UPLOAD_RETRIES" ]; then
            echo -e "${RED}❌ Failed to upload $(basename "$file") after ${UPLOAD_RETRIES} attempts.${NC}"
            return 1
        fi

        local sleep_s=$((UPLOAD_SLEEP_BASE * attempt))
        echo -e "${YELLOW}⏳ Upload failed; retry in ${sleep_s}s...${NC}"
        sleep "$sleep_s"
        attempt=$((attempt + 1))
    done
}

upload_asset "$DMG_ARM64"
upload_asset "$DMG_X86_64"

PAGES_WAIT_TIMEOUT_SECONDS="${PAGES_WAIT_TIMEOUT_SECONDS:-600}"
PAGES_WAIT_INTERVAL_SECONDS="${PAGES_WAIT_INTERVAL_SECONDS:-5}"
PAGES_WAIT_STRICT="${PAGES_WAIT_STRICT:-1}"
APPCAST_URL="${APPCAST_URL:-https://linhay.github.io/nolon/appcast.xml}"

wait_for_pages_and_appcast() {
    local waited=0
    local build_status=""

    echo -e "${YELLOW}⚙️  Ensuring GitHub Pages is configured...${NC}"
    gh api repos/:owner/:repo/pages -X POST -f source='{"branch":"main","path":"/docs"}' --silent || true

    echo -e "${YELLOW}🚧 Triggering GitHub Pages build...${NC}"
    gh api -X POST repos/:owner/:repo/pages/builds --silent >/dev/null 2>&1 || true

    echo -e "${YELLOW}⏳ Waiting for Pages build (timeout: ${PAGES_WAIT_TIMEOUT_SECONDS}s)...${NC}"
    waited=0
    while [ "$waited" -lt "$PAGES_WAIT_TIMEOUT_SECONDS" ]; do
        build_status="$(gh api repos/:owner/:repo/pages/builds/latest --jq '.status' 2>/dev/null || echo unknown)"
        if [ "$build_status" = "built" ]; then
            echo -e "${GREEN}✅ GitHub Pages build completed.${NC}"
            break
        fi
        if [ "$build_status" = "errored" ] || [ "$build_status" = "failed" ]; then
            echo -e "${RED}❌ GitHub Pages build status: ${build_status}${NC}"
            return 1
        fi
        sleep "$PAGES_WAIT_INTERVAL_SECONDS"
        waited=$((waited + PAGES_WAIT_INTERVAL_SECONDS))
    done

    if [ "$build_status" != "built" ]; then
        echo -e "${RED}❌ Timeout waiting for GitHub Pages build.${NC}"
        return 1
    fi

    echo -e "${YELLOW}🔎 Verifying online appcast contains ${VERSION}...${NC}"
    waited=0
    while [ "$waited" -lt "$PAGES_WAIT_TIMEOUT_SECONDS" ]; do
        if curl -fsSL "${APPCAST_URL}?t=$(date +%s)" | grep -q "<sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>"; then
            echo -e "${GREEN}✅ Online appcast is updated for ${VERSION}.${NC}"
            return 0
        fi
        sleep "$PAGES_WAIT_INTERVAL_SECONDS"
        waited=$((waited + PAGES_WAIT_INTERVAL_SECONDS))
    done

    echo -e "${RED}❌ Timeout waiting for online appcast to include ${VERSION}.${NC}"
    return 1
}

if ! wait_for_pages_and_appcast; then
    if [ "$PAGES_WAIT_STRICT" = "1" ]; then
        echo -e "${RED}❌ Release kept as draft: appcast is not ready yet.${NC}"
        echo -e "${YELLOW}Tip: once appcast is live, publish manually:${NC} gh release edit ${TAG} --draft=false --latest"
        exit 1
    fi
    echo -e "${YELLOW}⚠️  Continuing despite Pages/appcast not ready (PAGES_WAIT_STRICT=0).${NC}"
fi

echo -e "${YELLOW}✅ Assets uploaded. Publishing release ${TAG}...${NC}"
gh release edit "$TAG" --draft=false --latest

echo -e "${GREEN}✅ Release ${TAG} published successfully!${NC}"
echo -e "${GREEN}📍 View at: $(gh repo view --json url -q .url)/releases/tag/${TAG}${NC}"
