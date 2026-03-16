#!/bin/bash
set -e

# PixPets Release Script
# Usage: ./scripts/release.sh [version]
# If version is omitted, reads from VERSION file
#
# Environment:
#   SKIP_NOTARIZE=1  Skip notarization (for testing)
#   SKIP_BUILD=1     Skip build (use existing DMG in dist/)
#   GITHUB_REPO      Override repo (default: Evgenii-Konev/pixpets)
#   TAP_REPO         Override tap repo (default: Evgenii-Konev/homebrew-tap)

VERSION="${1:-$(cat VERSION 2>/dev/null)}"
if [ -z "$VERSION" ]; then
    echo "Error: No version specified and no VERSION file found."
    exit 1
fi

GITHUB_REPO="${GITHUB_REPO:-Evgenii-Konev/pixpets}"
TAP_REPO="${TAP_REPO:-Evgenii-Konev/homebrew-tap}"
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
if [ "${SKIP_BUILD}" != "1" ]; then
    echo "--- Step 1: Build distribution ---"
    VERSION="${VERSION}" make distribute
else
    echo "--- Step 1: Skipped (SKIP_BUILD=1) ---"
    if [ ! -f "${DMG_PATH}" ]; then
        echo "Error: ${DMG_PATH} not found. Build first or unset SKIP_BUILD."
        exit 1
    fi
fi

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
brew tap Evgenii-Konev/tap
brew install --cask pixpets
\`\`\`

After install, PixPets automatically configures hooks for Claude Code, Codex, Cursor, and OpenCode.

### Manual Install

Download \`${DISPLAY_NAME}-${VERSION}.dmg\`, open it, and drag PixPets to Applications.

### SHA256
\`\`\`
${SHA256}  ${DISPLAY_NAME}-${VERSION}.dmg
\`\`\`
EOF
)"

# Step 5: Update cask formula in homebrew-tap repo
echo ""
echo "--- Step 5: Updating cask formula in homebrew-tap ---"
TEMP_TAP=$(mktemp -d)
gh repo clone "${TAP_REPO}" "${TEMP_TAP}" -- --depth 1 2>/dev/null || \
    git clone "git@github-stm:${TAP_REPO}.git" "${TEMP_TAP}" --depth 1

CASK_FILE="${TEMP_TAP}/Casks/pixpets.rb"
if [ -f "${CASK_FILE}" ]; then
    sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "${CASK_FILE}"
    sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" "${CASK_FILE}"

    cd "${TEMP_TAP}"
    git add Casks/pixpets.rb
    git commit -m "$(cat <<COMMIT
chore: bump pixpets to v${VERSION}

Maintainer: ekonev@smartandpoint.com
COMMIT
)"
    git push
    echo "Updated homebrew-tap cask to v${VERSION}"
    cd "${PROJECT_DIR}"
else
    echo "Warning: Cask file not found in ${TAP_REPO}. Update manually."
fi
rm -rf "${TEMP_TAP}"

# Also update local copy
"${SCRIPT_DIR}/update-cask.sh" "${VERSION}" "${SHA256}" 2>/dev/null || true

echo ""
echo "=== Release v${VERSION} complete ==="
echo "DMG:     ${VERSIONED_DMG}"
echo "SHA256:  ${SHA256}"
echo "Release: https://github.com/${GITHUB_REPO}/releases/tag/v${VERSION}"
echo ""
echo "Users can install with:"
echo "  brew tap Evgenii-Konev/tap"
echo "  brew install --cask pixpets"
