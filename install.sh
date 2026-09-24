#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
INSTALL_DIR="${HOME}/.local/libexec/media-key-router"
BIN_DIR="${HOME}/.local/bin"
BIN_LINK="${BIN_DIR}/media-key-router"
KARABINER_DIR="${HOME}/.config/karabiner"
KARABINER_CONFIG="${KARABINER_DIR}/karabiner.json"
ASSET_DIR="${KARABINER_DIR}/assets/complex_modifications"
ASSET_FILE="${ASSET_DIR}/media-key-router.json"
RULE_DESCRIPTION="Smart F8 play/pause with configurable fallback"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This tool supports macOS only." >&2
  exit 1
fi

if [ ! -d /Applications/Karabiner-Elements.app ]; then
  echo "Karabiner-Elements is required but is not installed." >&2
  exit 1
fi

BREW_BIN=$(command -v brew 2>/dev/null || true)
if [ -z "$BREW_BIN" ] && [ -x /opt/homebrew/bin/brew ]; then
  BREW_BIN=/opt/homebrew/bin/brew
fi
if [ -z "$BREW_BIN" ]; then
  echo "Homebrew is required to install nowplaying-cli and jq." >&2
  exit 1
fi

if ! command -v nowplaying-cli >/dev/null 2>&1 \
    && [ ! -x /opt/homebrew/bin/nowplaying-cli ] \
    && [ ! -x /usr/local/bin/nowplaying-cli ]; then
  "$BREW_BIN" install nowplaying-cli
fi

if ! command -v jq >/dev/null 2>&1; then
  "$BREW_BIN" install jq
fi

install -d -m 755 "$INSTALL_DIR" "$BIN_DIR" "$ASSET_DIR"
install -m 755 "${ROOT_DIR}/bin/media-key-router" "${INSTALL_DIR}/media-key-router"
install -m 644 "${ROOT_DIR}/karabiner/media-key-router.json" "$ASSET_FILE"
if [ -e "$BIN_LINK" ] || [ -L "$BIN_LINK" ]; then
  if [ ! -L "$BIN_LINK" ] || [ "$(readlink "$BIN_LINK")" != "${INSTALL_DIR}/media-key-router" ]; then
    LINK_BACKUP="${BIN_LINK}.backup.$(date '+%Y%m%d-%H%M%S')"
    mv "$BIN_LINK" "$LINK_BACKUP"
    echo "Preserved the previous command as: $LINK_BACKUP"
  fi
fi
ln -sfn "${INSTALL_DIR}/media-key-router" "$BIN_LINK"

"${INSTALL_DIR}/media-key-router" default /Applications/Spotify.app >/dev/null

if [ ! -f "$KARABINER_CONFIG" ]; then
  echo "The router is installed, but Karabiner has not created its configuration yet."
  echo "Karabiner-Elements will open now. Complete its requested macOS permissions, then run:"
  echo "  ${ROOT_DIR}/install.sh"
  /usr/bin/open -a Karabiner-Elements
  exit 3
fi

if ! jq -e '.profiles | type == "array" and any(.selected == true)' "$KARABINER_CONFIG" >/dev/null; then
  echo "Karabiner has no selected profile; open it once and rerun this installer." >&2
  /usr/bin/open -a Karabiner-Elements
  exit 3
fi

BACKUP_FILE="${KARABINER_CONFIG}.media-key-router-backup.$(date '+%Y%m%d-%H%M%S')"
TEMP_FILE=$(mktemp "${KARABINER_DIR}/karabiner.json.XXXXXX")
trap 'rm -f "$TEMP_FILE"' EXIT
cp "$KARABINER_CONFIG" "$BACKUP_FILE"

jq --arg description "$RULE_DESCRIPTION" --slurpfile asset "$ASSET_FILE" '
  (.profiles[] | select(.selected == true) | .complex_modifications.rules) |=
    ((. // []) | map(select(.description != $description)) + [$asset[0].rules[0]])
' "$KARABINER_CONFIG" > "$TEMP_FILE"

jq empty "$TEMP_FILE"
chmod --reference="$KARABINER_CONFIG" "$TEMP_FILE" 2>/dev/null || chmod 600 "$TEMP_FILE"
mv "$TEMP_FILE" "$KARABINER_CONFIG"
trap - EXIT

echo "Installed and enabled Media Key Router."
echo "Backup: $BACKUP_FILE"
echo "Check: $BIN_LINK status"
