#!/usr/bin/env bash
# Installs the Godot editor (and, with --templates, the Android export
# templates) for CI. Reuses cached copies when present.
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7.2}"
RELEASE="${VERSION}-stable"
BASE="https://github.com/godotengine/godot/releases/download/${RELEASE}"
DIR="${GODOT_DIR:-$HOME/godot}"
TEMPLATES="$HOME/.local/share/godot/export_templates/${VERSION}.stable"

mkdir -p "$DIR"
if [ ! -x "$DIR/godot" ]; then
  echo "Downloading Godot ${RELEASE}"
  curl -fsSL --retry 4 -o /tmp/godot.zip "$BASE/Godot_v${RELEASE}_linux.x86_64.zip"
  unzip -q -o /tmp/godot.zip -d "$DIR"
  mv "$DIR/Godot_v${RELEASE}_linux.x86_64" "$DIR/godot"
  rm /tmp/godot.zip
fi
sudo ln -sf "$DIR/godot" /usr/local/bin/godot
godot --version

if [ "${1:-}" = "--templates" ]; then
  if [ ! -f "$TEMPLATES/android_debug.apk" ]; then
    echo "Downloading export templates"
    curl -fsSL --retry 4 -o /tmp/templates.tpz "$BASE/Godot_v${RELEASE}_export_templates.tpz"
    rm -rf /tmp/templates && mkdir -p /tmp/templates "$TEMPLATES"
    # Only the Android templates are needed; skip the other platforms.
    unzip -q /tmp/templates.tpz 'templates/android_*' 'templates/version.txt' -d /tmp/templates
    mv /tmp/templates/templates/* "$TEMPLATES/"
    rm -rf /tmp/templates /tmp/templates.tpz
  fi
  ls -la "$TEMPLATES"
fi
