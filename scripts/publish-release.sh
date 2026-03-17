#!/bin/bash
set -e

# Publish PixPets release: GitHub Release + Homebrew tap update
# Called by `make distribute` after build/sign/notarize/DMG
# Usage: ./scripts/publish-release.sh <version>

VERSION="${1:?Usage: $0 <version>}"
DISPLAY_NAME="PixPets"
GITHUB_REPO="Evgenii-Konev/pixpets"
TAP_REPO="Evgenii-Konev/homebrew-tap"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
DMG_PATH="${PROJECT_DIR}/dist/${DISPLAY_NAME}.dmg"
VERSIONED_DMG="${PROJECT_DIR}/dist/${DISPLAY_NAME}-${VERSION}.dmg"

# Preflight
command -v gh >/dev/null 2>&1 || { echo "Error: gh CLI not installed. Run: brew install gh"; exit 1; }

if [ ! -f "${DMG_PATH}" ]; then
    echo "Error: ${DMG_PATH} not found."
    exit 1
fi

# Create versioned DMG copy
cp "${DMG_PATH}" "${VERSIONED_DMG}"

# Compute SHA256
SHA256=$(shasum -a 256 "${VERSIONED_DMG}" | awk '{print $1}')
echo "SHA256: ${SHA256}"

# Create GitHub Release
echo "--- Creating GitHub Release v${VERSION} ---"
gh release create "v${VERSION}" "${VERSIONED_DMG}" \
    --repo "${GITHUB_REPO}" \
    --title "${DISPLAY_NAME} v${VERSION}" \
    --notes "## ${DISPLAY_NAME} v${VERSION}

### Install via Homebrew

\`\`\`bash
brew tap ${TAP_REPO%%/*}/tap
brew install --cask pixpets
\`\`\`

### Manual Install

Download \`${DISPLAY_NAME}-${VERSION}.dmg\`, open it, and drag ${DISPLAY_NAME} to Applications.

### SHA256
\`\`\`
${SHA256}  ${DISPLAY_NAME}-${VERSION}.dmg
\`\`\`"

# Update homebrew-tap
echo ""
echo "--- Updating homebrew-tap ---"
TEMP_TAP=$(mktemp -d)
git clone "git@github-stm:${TAP_REPO}.git" "${TEMP_TAP}" --depth 1 2>/dev/null || \
    gh repo clone "${TAP_REPO}" "${TEMP_TAP}" -- --depth 1

CASK_FILE="${TEMP_TAP}/Casks/pixpets.rb"
if [ -f "${CASK_FILE}" ]; then
    sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "${CASK_FILE}"
    sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" "${CASK_FILE}"

    cd "${TEMP_TAP}"
    git add Casks/pixpets.rb
    git commit -m "chore: bump pixpets to v${VERSION}"
    git push
    echo "Updated homebrew-tap cask to v${VERSION}"
    cd "${PROJECT_DIR}"
else
    echo "Warning: Cask file not found in ${TAP_REPO}. Update manually."
fi
rm -rf "${TEMP_TAP}"

# Update local cask copy
"${SCRIPT_DIR}/update-cask.sh" "${VERSION}" "${SHA256}" 2>/dev/null || true

echo ""
echo "=== Distribution complete ==="
echo "DMG:     ${VERSIONED_DMG}"
echo "SHA256:  ${SHA256}"
echo "Release: https://github.com/${GITHUB_REPO}/releases/tag/v${VERSION}"
echo ""
echo "Users can install/upgrade with:"
echo "  brew tap Evgenii-Konev/tap"
echo "  brew install --cask pixpets"
