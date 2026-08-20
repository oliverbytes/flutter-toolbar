#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Flunner macOS .dmg Installer & Release Packager
# ==============================================================================

APP_NAME="Flunner"
BUNDLE_ID="com.flunner.app"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/dist"
BUILD_DIR="$ROOT_DIR/.build/release"
ENTITLEMENTS_FILE="$ROOT_DIR/Sources/Flunner/Flunner.entitlements"
PROJECT_FILE="$ROOT_DIR/Flunner.xcodeproj"
PROJECT_YML="$ROOT_DIR/project.yml"

# Auto-detect Developer ID Application certificate from Keychain if not explicitly set
AUTO_DEV_ID=$(security find-identity -p codesigning -v 2>/dev/null | grep "Developer ID Application:" | head -n 1 | awk -F '"' '{print $2}' || true)
SIGNING_IDENTITY="${APPLE_SIGNING_IDENTITY:-${AUTO_DEV_ID:-"-"}}"
# Auto-detect Notary Keychain profile if not explicitly set
AUTO_NOTARY_PROFILE="FlunnerNotary"
if security find-generic-password -s "notarytool" -a "FlunnerNotary" >/dev/null 2>&1 || xcrun notarytool history --keychain-profile "$AUTO_NOTARY_PROFILE" >/dev/null 2>&1; then
  DEFAULT_NOTARY_PROFILE="$AUTO_NOTARY_PROFILE"
else
  DEFAULT_NOTARY_PROFILE=""
fi
NOTARY_PROFILE="${NOTARIZATION_KEYCHAIN_PROFILE:-${NOTARY_PROFILE:-$DEFAULT_NOTARY_PROFILE}}"

# Extract default version from project.yml or fallback to 1.0.0
DEFAULT_VERSION="1.0.0"
if [ -f "$PROJECT_YML" ]; then
  EXTRACTED_VERSION=$(grep 'MARKETING_VERSION:' "$PROJECT_YML" | head -n 1 | awk '{print $2}' | tr -d '"' || true)
  if [ -n "$EXTRACTED_VERSION" ]; then
    DEFAULT_VERSION="$EXTRACTED_VERSION"
  fi
fi
VERSION="$DEFAULT_VERSION"
SKIP_BUILD=false
CLEAN=false

# ------------------------------------------------------------------------------
# Help & Usage
# ------------------------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -v, --version <ver>      Set release version (default: $DEFAULT_VERSION)
  -o, --output-dir <dir>   Set output directory for distribution artifacts (default: dist)
  -s, --identity <id>      Code signing identity (default: Developer ID Application from Keychain)
      --skip-build         Skip xcodebuild and package existing .app in build directory
      --clean              Clean build artifacts before building
  -h, --help               Show this help message

Environment Variables:
  APPLE_SIGNING_IDENTITY   Code signing identity name or hash
  NOTARIZATION_KEYCHAIN_PROFILE  Keychain profile name for notarytool (e.g. FlunnerNotary)
  NOTARIZATION_APPLE_ID    Apple ID email for notarization
  NOTARIZATION_PASSWORD    App-specific password for notarization
  NOTARIZATION_TEAM_ID     Apple Developer Team ID
EOF
  exit 0
}

# ------------------------------------------------------------------------------
# Parse Arguments
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)
      VERSION="${2#v}" # strip leading 'v' if provided e.g. v1.0.0 -> 1.0.0
      shift 2
      ;;
    -o|--output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -s|--identity)
      SIGNING_IDENTITY="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=true
      shift
      ;;
    --clean)
      CLEAN=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      usage
      ;;
  esac
done

echo "============================================================"
echo " Packaging $APP_NAME v$VERSION for macOS"
echo "============================================================"
echo "  Root directory:       $ROOT_DIR"
echo "  Output directory:     $OUTPUT_DIR"
echo "  Signing identity:     $SIGNING_IDENTITY"
echo "  Notary profile:       ${NOTARY_PROFILE:-"(none)"}"
echo "============================================================"

# Ensure output and build directories exist
mkdir -p "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"

# ------------------------------------------------------------------------------
# Helper: Submit to Notarytool
# ------------------------------------------------------------------------------
submit_to_notary() {
  local target_file="$1"
  local item_label="$2"
  
  if [ -n "$NOTARY_PROFILE" ]; then
    echo "==> Submitting $item_label for Apple Notarization via keychain profile '$NOTARY_PROFILE'..."
    xcrun notarytool submit "$target_file" --keychain-profile "$NOTARY_PROFILE" --wait
  elif [ -n "${NOTARIZATION_KEY_FILE:-}" ] && [ -n "${NOTARIZATION_KEY_ID:-}" ] && [ -n "${NOTARIZATION_ISSUER_ID:-}" ]; then
    echo "==> Submitting $item_label for Apple Notarization via App Store Connect API Key..."
    xcrun notarytool submit "$target_file" \
      --key "$NOTARIZATION_KEY_FILE" \
      --key-id "$NOTARIZATION_KEY_ID" \
      --issuer "$NOTARIZATION_ISSUER_ID" \
      --wait
  elif [ -n "${NOTARIZATION_APPLE_ID:-}" ] && [ -n "${NOTARIZATION_PASSWORD:-}" ] && [ -n "${NOTARIZATION_TEAM_ID:-}" ]; then
    echo "==> Submitting $item_label for Apple Notarization via Apple ID credentials..."
    xcrun notarytool submit "$target_file" \
      --apple-id "$NOTARIZATION_APPLE_ID" \
      --password "$NOTARIZATION_PASSWORD" \
      --team-id "$NOTARIZATION_TEAM_ID" \
      --wait
  else
    return 1
  fi
  return 0
}

# ------------------------------------------------------------------------------
# 1. Clean Build Directory if Requested
# ------------------------------------------------------------------------------
if [ "$CLEAN" = true ]; then
  echo "==> Cleaning build artifacts..."
  rm -rf "$BUILD_DIR" "$OUTPUT_DIR"
  mkdir -p "$OUTPUT_DIR" "$BUILD_DIR"
fi

# ------------------------------------------------------------------------------
# 2. Build Release Application Bundle via xcodebuild
# ------------------------------------------------------------------------------
APP_BUNDLE="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ "$SKIP_BUILD" = false ]; then
  echo "==> Building $APP_NAME in Release mode..."
  xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    build \
    CODE_SIGNING_ALLOWED=NO

  if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: Build succeeded but $APP_BUNDLE was not found!" >&2
    exit 1
  fi
else
  if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: --skip-build specified, but $APP_BUNDLE does not exist!" >&2
    exit 1
  fi
  echo "==> Using existing application bundle: $APP_BUNDLE"
fi

# ------------------------------------------------------------------------------
# 3. Code Sign Application Bundle
# ------------------------------------------------------------------------------
echo "==> Signing $APP_NAME.app with identity: '$SIGNING_IDENTITY'..."
if [ "$SIGNING_IDENTITY" = "-" ]; then
  echo "    (Using ad-hoc signature with entitlements)"
  codesign --force --deep --sign - \
    --entitlements "$ENTITLEMENTS_FILE" \
    --options runtime \
    "$APP_BUNDLE"
else
  echo "    (Using certificate signature: $SIGNING_IDENTITY)"
  codesign --force --deep --sign "$SIGNING_IDENTITY" \
    --entitlements "$ENTITLEMENTS_FILE" \
    --options runtime \
    --timestamp \
    "$APP_BUNDLE"
fi

echo "==> Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" || true

# ------------------------------------------------------------------------------
# 4. Notarize & Staple Application Bundle (CRUCIAL for Homebrew Cask & DMG)
# ------------------------------------------------------------------------------
if [ "$SIGNING_IDENTITY" != "-" ]; then
  TEMP_APP_ARCHIVE="$BUILD_DIR/temp_app_for_notarization.zip"
  rm -f "$TEMP_APP_ARCHIVE"
  (cd "$BUILD_DIR/Build/Products/Release" && ditto -c -k --keepParent "$APP_NAME.app" "$TEMP_APP_ARCHIVE")

  if submit_to_notary "$TEMP_APP_ARCHIVE" "$APP_NAME.app"; then
    echo "==> Stapling notarization ticket to $APP_NAME.app..."
    xcrun stapler staple "$APP_BUNDLE"
    xcrun stapler validate "$APP_BUNDLE"
  else
    echo "==> Skipping App Bundle Notarization (no active credentials configured)."
  fi
  rm -f "$TEMP_APP_ARCHIVE"
fi

# ------------------------------------------------------------------------------
# 5. Create DMG Staging Directory with the STAPLED App Bundle
# ------------------------------------------------------------------------------
STAGING_DIR="$ROOT_DIR/.build/dmg_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

echo "==> Staging files for DMG creation..."
cp -R "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"

# Create symbolic link to /Applications
ln -s /Applications "$STAGING_DIR/Applications"

# ------------------------------------------------------------------------------
# 6. Create .DMG Disk Image
# ------------------------------------------------------------------------------
DMG_NAME="$APP_NAME-$VERSION.dmg"
CANONICAL_DMG="$OUTPUT_DIR/$APP_NAME.dmg"
VERSIONED_DMG="$OUTPUT_DIR/$DMG_NAME"

rm -f "$CANONICAL_DMG" "$VERSIONED_DMG"

echo "==> Creating compressed .dmg disk image..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$VERSIONED_DMG"

# Code sign the DMG if signing identity is available and not ad-hoc
if [ "$SIGNING_IDENTITY" != "-" ]; then
  echo "==> Signing .dmg image..."
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$VERSIONED_DMG" || true
fi

# ------------------------------------------------------------------------------
# 7. Create .ZIP Archive (from the stapled app)
# ------------------------------------------------------------------------------
ZIP_NAME="$APP_NAME-$VERSION.zip"
CANONICAL_ZIP="$OUTPUT_DIR/$APP_NAME.zip"
VERSIONED_ZIP="$OUTPUT_DIR/$ZIP_NAME"

rm -f "$CANONICAL_ZIP" "$VERSIONED_ZIP"
echo "==> Creating .zip archive from stapled app bundle..."
(cd "$BUILD_DIR/Build/Products/Release" && ditto -c -k --keepParent "$APP_NAME.app" "$VERSIONED_ZIP")

# ------------------------------------------------------------------------------
# 8. Notarize & Staple .DMG Image
# ------------------------------------------------------------------------------
if [ "$SIGNING_IDENTITY" != "-" ]; then
  if submit_to_notary "$VERSIONED_DMG" "$DMG_NAME"; then
    echo "==> Stapling notarization ticket to $DMG_NAME..."
    xcrun stapler staple "$VERSIONED_DMG"
    xcrun stapler validate "$VERSIONED_DMG"
  else
    echo "==> Skipping DMG Notarization (no active credentials configured)."
  fi
fi

# Copy canonical release files from notarized/stapled versions
cp -f "$VERSIONED_DMG" "$CANONICAL_DMG"
cp -f "$VERSIONED_ZIP" "$CANONICAL_ZIP"

# ------------------------------------------------------------------------------
# 9. Gatekeeper Assessment Verification
# ------------------------------------------------------------------------------
echo "==> Validating Gatekeeper assessment..."
spctl -a -t open --context context:primary-signature -v "$CANONICAL_DMG" 2>&1 || true
spctl -a -t execute -v "$APP_BUNDLE" 2>&1 || true

# ------------------------------------------------------------------------------
# 10. Generate SHA256 Checksums
# ------------------------------------------------------------------------------
echo "==> Generating SHA256 checksums..."
(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
  shasum -a 256 "$APP_NAME.dmg" > "$APP_NAME.dmg.sha256"
  shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256"
  shasum -a 256 "$APP_NAME.zip" > "$APP_NAME.zip.sha256"
)

# ------------------------------------------------------------------------------
# 9. Update Homebrew Cask Definition (if Casks directory exists)
# ------------------------------------------------------------------------------
CASK_FILE="$ROOT_DIR/Casks/flunner.rb"
if [ -d "$ROOT_DIR/Casks" ]; then
  echo "==> Updating Homebrew Cask file ($CASK_FILE)..."
  DMG_SHA256=$(cat "$OUTPUT_DIR/$APP_NAME.dmg.sha256" | awk '{print $1}')
  cat <<EOF > "$CASK_FILE"
cask "flunner" do
  version "$VERSION"
  sha256 "$DMG_SHA256"

  url "https://github.com/stackwares/flunner/releases/download/v#{version}/Flunner.dmg"
  name "Flunner"
  desc "Workbench for the Flutter run-observe-reload loop"
  homepage "https://github.com/stackwares/flunner"

  depends_on macos: :sequoia

  app "Flunner.app"

  zap trash: [
    "~/Library/Application Support/Flunner",
    "~/Library/Caches/com.flunner.app",
    "~/Library/Preferences/com.flunner.app.plist",
    "~/Library/Saved Application State/com.flunner.app.savedState",
  ]
end
EOF
fi

# ------------------------------------------------------------------------------
# 10. Summary
# ------------------------------------------------------------------------------
echo ""
echo "============================================================"
echo " Packaging Completed Successfully!"
echo "============================================================"
echo "Artifacts generated in: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"
echo ""
echo "SHA256 Checksums:"
cat "$OUTPUT_DIR/$DMG_NAME.sha256"
cat "$OUTPUT_DIR/$ZIP_NAME.sha256"
echo "============================================================"
