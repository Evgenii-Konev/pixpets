#!/bin/bash
set -e

# Updates the Homebrew cask formula with new version and SHA256
# Usage: ./scripts/update-cask.sh <version> <sha256>

VERSION="${1:?Usage: $0 <version> <sha256>}"
SHA256="${2:?Usage: $0 <version> <sha256>}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CASK_FILE="${SCRIPT_DIR}/../homebrew/Casks/pixpets.rb"

if [ ! -f "${CASK_FILE}" ]; then
    echo "Error: Cask formula not found at ${CASK_FILE}"
    exit 1
fi

echo "Updating cask formula..."
echo "  Version: ${VERSION}"
echo "  SHA256:  ${SHA256}"

# Update version
sed -i '' "s/version \".*\"/version \"${VERSION}\"/" "${CASK_FILE}"

# Update sha256
sed -i '' "s/sha256 \".*\"/sha256 \"${SHA256}\"/" "${CASK_FILE}"

echo "Updated ${CASK_FILE}"
