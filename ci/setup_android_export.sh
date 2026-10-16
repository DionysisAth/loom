#!/usr/bin/env bash
# Points Godot at the runner's JDK and Android SDK and creates a debug
# keystore. Needs JAVA_HOME and ANDROID_HOME (or ANDROID_SDK_ROOT).
set -euo pipefail

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?Android SDK not found}}"
VERSION="${GODOT_VERSION:-4.7.2}"
MINOR="$(echo "$VERSION" | cut -d. -f1-2)"
KEYSTORE="$HOME/.android/loom-debug.keystore"

# Godot 4.7 needs build-tools 35.0.1 and platform 35.
SDKMANAGER="$SDK/cmdline-tools/latest/bin/sdkmanager"
yes | "$SDKMANAGER" --licenses > /dev/null || true
"$SDKMANAGER" --install "platform-tools" "build-tools;35.0.1" "platforms;android-35" > /dev/null

mkdir -p "$HOME/.android"
if [ ! -f "$KEYSTORE" ]; then
  keytool -genkeypair -v -keystore "$KEYSTORE" -storepass android -keypass android \
    -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" \
    -keyalg RSA -keysize 2048 -validity 10000 > /dev/null
fi

mkdir -p "$HOME/.config/godot"
cat > "$HOME/.config/godot/editor_settings-${MINOR}.tres" <<TRES
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "${JAVA_HOME}"
export/android/android_sdk_path = "${SDK}"
export/android/debug_keystore = "${KEYSTORE}"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
TRES

{
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PATH=${KEYSTORE}"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey"
  echo "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android"
} >> "${GITHUB_ENV:-/dev/null}"
echo "Android export configured (SDK: $SDK, JDK: $JAVA_HOME)"
