#!/bin/bash
set -e

# Configuration
DISPLAY_NAME="PixPets"
VOLUME_NAME="PixPets"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
BUILD_DIR="${PROJECT_DIR}/dist"
APP_BUNDLE="${BUILD_DIR}/${DISPLAY_NAME}.app"
DMG_PATH="${BUILD_DIR}/${DISPLAY_NAME}.dmg"
TEMP_DMG="${BUILD_DIR}/temp_${DISPLAY_NAME}.dmg"
DMG_TEMP_DIR="${BUILD_DIR}/dmg_staging"

if [ -z "${CODE_SIGN_IDENTITY}" ]; then
    echo "Error: CODE_SIGN_IDENTITY env var is not set." >&2
    exit 1
fi

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "Error: ${APP_BUNDLE} not found. Run create-app-bundle.sh first."
    exit 1
fi

echo "=== Creating ${DISPLAY_NAME}.dmg ==="

# Clean staging
rm -rf "${DMG_TEMP_DIR}" "${DMG_PATH}" "${TEMP_DMG}"
mkdir -p "${DMG_TEMP_DIR}"

# Copy app and create Applications symlink
cp -R "${APP_BUNDLE}" "${DMG_TEMP_DIR}/"
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create read-write DMG for customization
echo "Creating temporary DMG..."
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov -format UDRW \
    "${TEMP_DMG}"

# Mount and customize
echo "Customizing DMG layout..."
DEVICE=$(hdiutil attach -readwrite -noverify "${TEMP_DMG}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_POINT="/Volumes/${VOLUME_NAME}"
sleep 2

# Configure DMG window via AppleScript
osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 200, 700, 500}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set position of item "${DISPLAY_NAME}.app" of container window to {130, 150}
        set position of item "Applications" of container window to {370, 150}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
EOF

sync
sleep 1
hdiutil detach "${DEVICE}"

# Convert to compressed final DMG
echo "Compressing DMG..."
hdiutil convert "${TEMP_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_PATH}"

rm -f "${TEMP_DMG}"

# Sign DMG
echo "Signing DMG..."
codesign --sign "${CODE_SIGN_IDENTITY}" --timestamp "${DMG_PATH}"
codesign --verify --verbose "${DMG_PATH}"

# Clean up
rm -rf "${DMG_TEMP_DIR}"

echo "=== DMG created ==="
echo "Path: ${DMG_PATH}"
echo "Size: $(du -sh "${DMG_PATH}" | cut -f1)"
echo ""
echo "To notarize the DMG:"
echo "  xcrun notarytool submit ${DMG_PATH} --keychain-profile pixpets-notary --wait"
echo "  xcrun stapler staple ${DMG_PATH}"
