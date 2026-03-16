#!/bin/bash
set -e

# Configuration
APP_NAME="pixpets"
DISPLAY_NAME="PixPets"
BUNDLE_ID="com.smartandpoint.pixpets"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/.."
BUILD_DIR="${PROJECT_DIR}/dist"
APP_BUNDLE="${BUILD_DIR}/${DISPLAY_NAME}.app"

echo "=== Creating ${DISPLAY_NAME}.app bundle ==="

# Clean
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build release binary (universal: arm64 + x86_64)
echo "Building release binary (arm64)..."
cd "${PROJECT_DIR}"
swift build -c release --arch arm64

echo "Building release binary (x86_64)..."
swift build -c release --arch x86_64

# Create universal binary
echo "Creating universal binary..."
BINARY_ARM64="${PROJECT_DIR}/.build/arm64-apple-macosx/release/${APP_NAME}"
BINARY_X86="${PROJECT_DIR}/.build/x86_64-apple-macosx/release/${APP_NAME}"

mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

if [ -f "${BINARY_X86}" ]; then
    lipo -create "${BINARY_ARM64}" "${BINARY_X86}" -output "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
    echo "Universal binary created (arm64 + x86_64)"
else
    cp "${BINARY_ARM64}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
    echo "arm64-only binary (x86_64 build failed, continuing)"
fi

chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Create Info.plist
echo "Creating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2026 Evgenii Konev. All rights reserved.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
</dict>
</plist>
PLIST

# Create PkgInfo
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Bundle hook scripts into Resources
echo "Bundling hook scripts..."
cp "${PROJECT_DIR}/hooks/pixpets-hook.sh" "${APP_BUNDLE}/Contents/Resources/pixpets-hook.sh"
chmod +x "${APP_BUNDLE}/Contents/Resources/pixpets-hook.sh"
if [ -f "${PROJECT_DIR}/hooks/pixpets-opencode-plugin.js" ]; then
    cp "${PROJECT_DIR}/hooks/pixpets-opencode-plugin.js" "${APP_BUNDLE}/Contents/Resources/pixpets-opencode-plugin.js"
fi

echo "=== ${DISPLAY_NAME}.app created at ${APP_BUNDLE} ==="
echo "Binary: $(file "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}")"
echo "Size: $(du -sh "${APP_BUNDLE}" | cut -f1)"
