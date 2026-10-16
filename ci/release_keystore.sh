#!/usr/bin/env bash
# Provides the release signing key for the AAB export. Uses the repository
# secrets when set; otherwise signs with a throwaway key so the pipeline still
# proves the release build works (that AAB cannot be uploaded to Google Play).
set -euo pipefail

KS="$HOME/.android/loom-release.keystore"
mkdir -p "$(dirname "$KS")"
if [ -n "${KEYSTORE_BASE64:-}" ]; then
  echo "$KEYSTORE_BASE64" | base64 -d > "$KS"
  ALIAS="${KEYSTORE_ALIAS:?ANDROID_KEYSTORE_ALIAS secret missing}"
  PASS="${KEYSTORE_PASSWORD:?ANDROID_KEYSTORE_PASSWORD secret missing}"
  echo "Signing with the upload key from repository secrets"
else
  echo "::warning::ANDROID_KEYSTORE_BASE64 is not set, so the AAB is signed with a throwaway key and cannot be uploaded to Google Play."
  ALIAS="loom"
  PASS="ci$(od -An -N8 -tx8 /dev/urandom | tr -d ' ')"
  keytool -genkeypair -keystore "$KS" -storepass "$PASS" -keypass "$PASS" -alias "$ALIAS" \
    -dname "CN=Loom CI" -keyalg RSA -keysize 2048 -validity 10000 > /dev/null
fi
echo "::add-mask::$PASS"
{
  echo "GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$KS"
  echo "GODOT_ANDROID_KEYSTORE_RELEASE_USER=$ALIAS"
  echo "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$PASS"
} >> "${GITHUB_ENV:-/dev/null}"
