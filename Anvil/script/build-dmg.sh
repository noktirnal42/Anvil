#!/usr/bin/env bash
# build-dmg.sh
# Builds Anvil, codesigns it, creates a DMG, and prepares it for notarization.
#
# Usage:
#   ./script/build-dmg.sh [--sign IDENTITY] [--notarize]
#
# Requires: Xcode 27, an Apple Developer ID for signing/notarization.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Anvil"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR="${ROOT_DIR}/.build/out/Products/Release"
APP_PATH="${BUILD_DIR}/${APP_BUNDLE}"
DMG_PATH="${ROOT_DIR}/${APP_NAME}-$(date +%Y%m%d).dmg"
UNNOTARIZED_DMG="${ROOT_DIR}/${APP_NAME}-unsigned.dmg"

SIGN_IDENTITY=""
NOTARIZE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign) SIGN_IDENTITY="$2"; shift 2 ;;
    --notarize) NOTARIZE=1; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "==> Anvil build-dmg"
echo "ROOT_DIR: ${ROOT_DIR}"

echo "==> Building Anvil (Release)..."
(cd "${ROOT_DIR}" && swift build -c release)

if [ ! -f "${APP_PATH}/Contents/MacOS/Anvil" ]; then
  echo "ERROR: expected app bundle at ${APP_PATH}"
  exit 1
fi

if [[ -n "${SIGN_IDENTITY}" ]]; then
  echo "==> Codesigning app bundle with identity: ${SIGN_IDENTITY}"
  codesign --deep --force --sign "${SIGN_IDENTITY}" \
    --entitlements="${ROOT_DIR}/Anvil/Sources/AnvilApp/Entitlements.plist" \
    "${APP_PATH}"
fi

echo "==> Creating unsigned DMG: ${UNNOTARIZED_DMG}"
rm -f "${UNNOTARIZED_DMG}"
hdiutil create -srcfolder "${BUILD_DIR}" -volname "${APP_NAME}" \
  -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
  -format UDZO -o "${UNNOTARIZED_DMG}"

if [[ "${NOTARIZE}" -eq 1 ]]; then
  echo "==> Notarizing DMG with Apple..."
  xcrun notarytool submit "${UNNOTARIZED_DMG}" \
    --apple-id "${APPLE_ID:-}" \
    --team-id "${TEAM_ID:-}" \
    --wait \
    --output-format json > /private/var/folders/jd/zf9v8l9j7bx200284js3k6080000gn/T/opencode/notarize-result.json

  xcrun stapler staple "${UNNOTARIZED_DMG}"
  mv "${UNNOTARIZED_DMG}" "${DMG_PATH}"
  echo "==> Notarized DMG: ${DMG_PATH}"
else
  mv "${UNNOTARIZED_DMG}" "${DMG_PATH}"
  echo "==> Unsigned DMG (for local testing): ${DMG_PATH}"
  echo "   Re-run with --sign and --notarize for distribution."
fi

echo ""
echo "==> Release asset ready: ${DMG_PATH}"
echo "   Upload to a GitHub release and point the Sparkle appcast at it."
