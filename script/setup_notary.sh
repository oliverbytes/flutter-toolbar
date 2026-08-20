#!/usr/bin/env bash
set -euo pipefail

APPLE_ID="${1:-"nemoryoliver@gmail.com"}"
TEAM_ID="${2:-"V8V5US964Z"}"
PROFILE_NAME="FlunnerNotary"

echo "============================================================"
echo " Apple Notary Service Credential Setup"
echo "============================================================"
echo "  Apple ID:      $APPLE_ID"
echo "  Team ID:       $TEAM_ID"
echo "  Profile Name:  $PROFILE_NAME"
echo "============================================================"
echo ""
echo "Please enter your Apple App-Specific Password:"
echo "(Generate one at https://appleid.apple.com -> App-Specific Passwords)"
echo ""

xcrun notarytool store-credentials "$PROFILE_NAME" \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID"

echo ""
echo "✅ Notary profile '$PROFILE_NAME' saved to Keychain!"
echo "You can now run: ./script/build_dmg.sh"
