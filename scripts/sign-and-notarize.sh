#!/bin/bash
set -e

# Configuration
DISPLAY_NAME="PixPets"
BUNDLE_ID="com.smartandpoint.pixpets"
DEVELOPMENT_TEAM="8MSDJTBW2D"
CODE_SIGN_IDENTITY="5F4D15090C370E9C94626F89E4339DE03E75321C"

# Notarization config (set via env or keychain profile)
# Create profile: xcrun notarytool store-credentials "pixpets-notary" --apple-id YOUR_EMAIL --team-id 8MSDJTBW2D
NOTARY_PROFILE="${NOTARY_PROFILE:-pixpets-notary}"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
BUILD_DIR="${PROJECT_DIR}/dist"
APP_BUNDLE="${BUILD_DIR}/${DISPLAY_NAME}.app"

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "Error: ${APP_BUNDLE} not found. Run create-app-bundle.sh first."
    exit 1
fi

# --- Step 1: Entitlements ---
echo "=== Creating entitlements ==="
ENTITLEMENTS="${BUILD_DIR}/entitlements.plist"
cat > "${ENTITLEMENTS}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
PLIST

# --- Step 2: Code Sign ---
echo "=== Signing ${DISPLAY_NAME}.app ==="
codesign --force --deep --options runtime \
    --sign "${CODE_SIGN_IDENTITY}" \
    --entitlements "${ENTITLEMENTS}" \
    --timestamp \
    "${APP_BUNDLE}"

echo "Verifying signature..."
codesign --verify --verbose=2 "${APP_BUNDLE}"
echo "Signature OK"

echo "Gatekeeper assessment..."
spctl --assess --verbose=2 "${APP_BUNDLE}" 2>&1 || echo "(spctl may fail before notarization — that's OK)"

# --- Step 3: Notarize ---
if [ "${SKIP_NOTARIZE}" = "1" ]; then
    echo "=== Skipping notarization (SKIP_NOTARIZE=1) ==="
    exit 0
fi

echo "=== Notarizing ${DISPLAY_NAME}.app ==="

# Create ZIP for notarization
NOTARIZE_ZIP="${BUILD_DIR}/${DISPLAY_NAME}-notarize.zip"
ditto -c -k --keepParent "${APP_BUNDLE}" "${NOTARIZE_ZIP}"

echo "Submitting to Apple..."
xcrun notarytool submit "${NOTARIZE_ZIP}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait

echo "Stapling notarization ticket..."
xcrun stapler staple "${APP_BUNDLE}"

# Verify
echo "Final Gatekeeper assessment..."
spctl --assess --verbose=2 "${APP_BUNDLE}"

# Clean up
rm -f "${NOTARIZE_ZIP}" "${ENTITLEMENTS}"

echo "=== ${DISPLAY_NAME}.app signed and notarized ==="
