#!/bin/bash
set -e

# PixPets Release Script
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.0.0
#
# Environment:
#   SKIP_NOTARIZE=1  Skip notarization (for testing)
#   GITHUB_REPO      Override repo (default: Evgenii-Konev/pixelpets)

VERSION="${1:?Usage: $0 <version> (e.g. 1.0.0)}"
GITHUB_REPO="${GITHUB_REPO:-Evgenii-Konev/pixelpets}"
DISPLAY_NAME="PixPets"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
DMG_PATH="${PROJECT_DIR}/dist/${DISPLAY_NAME}.dmg"
VERSIONED_DMG="${PROJECT_DIR}/dist/${DISPLAY_NAME}-${VERSION}.dmg"

cd "${PROJECT_DIR}"

# Preflight checks
command -v gh >/dev/null 2>&1 || { echo "Error: gh CLI not installed. Run: brew install gh"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Error: gh not authenticated. Run: gh auth login"; exit 1; }

if git tag -l "v${VERSION}" | grep -q .; then
    echo "Error: Tag v${VERSION} already exists."
    exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
    echo "Error: Working directory not clean. Commit or stash changes first."
    exit 1
fi

echo "=== PixPets Release v${VERSION} ==="
echo ""

# Step 1: Build, sign, notarize, DMG
echo "--- Step 1: Build distribution ---"
VERSION="${VERSION}" make distribute

# Rename DMG with version
cp "${DMG_PATH}" "${VERSIONED_DMG}"

# Step 2: Compute SHA256
echo ""
echo "--- Step 2: Computing SHA256 ---"
SHA256=$(shasum -a 256 "${VERSIONED_DMG}" | awk '{print $1}')
echo "SHA256: ${SHA256}"

# Step 3: Create git tag
echo ""
echo "--- Step 3: Creating git tag ---"
git tag -a "v${VERSION}" -m "Release v${VERSION}"
git push origin "v${VERSION}"

# Step 4: Create GitHub Release
echo ""
echo "--- Step 4: Creating GitHub Release ---"
gh release create "v${VERSION}" "${VERSIONED_DMG}" \
    --repo "${GITHUB_REPO}" \
    --title "PixPets v${VERSION}" \
    --notes "$(cat <<EOF
## PixPets v${VERSION}

Menu bar app showing animated pixel pets for your AI coding agent sessions.

### Install via Homebrew

\`\`\`bash
brew tap Evgenii-Konev/pixpets https://github.com/Evgenii-Konev/pixelpets
brew install pixpets
\`\`\`

After install, run \`pixpets --install-hooks\` to set up Claude Code integration.

### Manual Install

Download \`${DISPLAY_NAME}-${VERSION}.dmg\`, open it, and drag PixPets to Applications.

### SHA256
\`\`\`
${SHA256}  ${DISPLAY_NAME}-${VERSION}.dmg
\`\`\`
EOF
)"

# Step 5: Update cask formula
echo ""
echo "--- Step 5: Updating cask formula ---"
"${SCRIPT_DIR}/update-cask.sh" "${VERSION}" "${SHA256}"

echo ""
echo "=== Release v${VERSION} complete ==="
echo "DMG:     ${VERSIONED_DMG}"
echo "SHA256:  ${SHA256}"
echo "Release: https://github.com/${GITHUB_REPO}/releases/tag/v${VERSION}"
echo ""
echo "Next steps:"
echo "  1. Commit the updated cask formula"
echo "  2. Test: brew tap Evgenii-Konev/pixpets https://github.com/Evgenii-Konev/pixelpets && brew install pixpets"
