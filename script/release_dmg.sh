#!/bin/zsh
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./script/release_dmg.sh --local
  ./script/release_dmg.sh --team-id ABCDE12345 [--notary-profile PROFILE]

Options:
  --local                 Build a local Release DMG for testing only.
  --team-id TEAM_ID       Apple Developer Team ID for Developer ID export.
  --notary-profile NAME   Keychain profile created with notarytool.
  --project PATH          Xcode project path relative to repo root.
  --scheme NAME           Xcode scheme to archive.
  --help                  Show this help.

Examples:
  ./script/release_dmg.sh --local
  ./script/release_dmg.sh --team-id ABCDE12345
  ./script/release_dmg.sh --team-id ABCDE12345 --notary-profile valeuray-ai-notary
EOF
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MODE="developer-id"
TEAM_ID=""
NOTARY_PROFILE=""
PROJECT_PATH="valeuray.xcodeproj"
SCHEME="Valeuray AI"
EXPORT_OPTIONS_TEMPLATE="$PROJECT_ROOT/Distribution/ExportOptions-DeveloperID.plist.template"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --local)
      MODE="local"
      shift
      ;;
    --team-id)
      TEAM_ID="${2:-}"
      shift 2
      ;;
    --notary-profile)
      NOTARY_PROFILE="${2:-}"
      shift 2
      ;;
    --project)
      PROJECT_PATH="${2:-}"
      shift 2
      ;;
    --scheme)
      SCHEME="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument '$1'" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "$MODE" == "developer-id" && -z "$TEAM_ID" ]]; then
  echo "error: pass --team-id <TEAM_ID> or use --local for a test build" >&2
  exit 1
fi

if [[ "$MODE" == "developer-id" && ! "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "error: team ID must be exactly 10 uppercase alphanumeric characters" >&2
  exit 1
fi

if [[ "$MODE" == "local" && -n "$NOTARY_PROFILE" ]]; then
  echo "error: notarization requires a Developer ID export; remove --local or omit --notary-profile" >&2
  exit 1
fi

PROJECT_FILE="$PROJECT_ROOT/$PROJECT_PATH"
if [[ ! -d "$PROJECT_FILE" ]]; then
  echo "error: project not found at $PROJECT_FILE" >&2
  exit 1
fi

if [[ ! -f "$EXPORT_OPTIONS_TEMPLATE" ]]; then
  echo "error: export options template not found at $EXPORT_OPTIONS_TEMPLATE" >&2
  exit 1
fi

RUN_ID="$(date '+%Y%m%d-%H%M%S')"
RUN_DIR="$PROJECT_ROOT/dist/release/$RUN_ID"
DERIVED_DATA_PATH="$RUN_DIR/DerivedData"
ARCHIVE_PATH="$RUN_DIR/$SCHEME.xcarchive"
EXPORT_PATH="$RUN_DIR/export"
DMG_STAGING_PATH="$RUN_DIR/dmg-root"

mkdir -p "$RUN_DIR"

if [[ "$MODE" == "local" ]]; then
  echo "Building local Release app..."
  xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

  APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products/Release" -maxdepth 1 -name '*.app' -print -quit)"
else
  EXPORT_OPTIONS_PATH="$RUN_DIR/ExportOptions.plist"
  sed "s/__TEAM_ID__/$TEAM_ID/g" "$EXPORT_OPTIONS_TEMPLATE" > "$EXPORT_OPTIONS_PATH"

  echo "Archiving signed Release app..."
  xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    -allowProvisioningUpdates \
    archive

  echo "Exporting Developer ID app..."
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
    -allowProvisioningUpdates

  APP_PATH="$(find "$EXPORT_PATH" -maxdepth 1 -name '*.app' -print -quit)"
fi

if [[ -z "${APP_PATH:-}" || ! -d "$APP_PATH" ]]; then
  echo "error: no .app bundle was produced" >&2
  exit 1
fi

APP_NAME="$(basename "$APP_PATH" .app)"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo '1.0')"
DMG_SAFE_NAME="$(echo "$APP_NAME" | tr ' ' '-')"
DMG_PATH="$RUN_DIR/${DMG_SAFE_NAME}-${APP_VERSION}-mac.dmg"

mkdir -p "$DMG_STAGING_PATH"
cp -R "$APP_PATH" "$DMG_STAGING_PATH/"
ln -s /Applications "$DMG_STAGING_PATH/Applications"

echo "Packaging DMG..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING_PATH" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "$NOTARY_PROFILE" ]]; then
  echo "Submitting DMG for notarization..."
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
fi

echo
echo "Release artifact created:"
echo "  App: $APP_PATH"
echo "  DMG: $DMG_PATH"

if [[ "$MODE" == "local" ]]; then
  echo
  echo "Local mode is for testing only. This DMG is not suitable for public download."
else
  echo
  echo "Developer ID export completed."
  if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "Next step: notarize the DMG with:"
    echo "  xcrun notarytool submit \"$DMG_PATH\" --keychain-profile <profile-name> --wait"
    echo "  xcrun stapler staple \"$DMG_PATH\""
  else
    echo "Notarization and stapling completed."
  fi
fi
