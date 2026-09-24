#!/bin/bash

set -euo pipefail

INSTALL_DIR="${HOME}/.local/libexec/media-key-router"
BIN_LINK="${HOME}/.local/bin/media-key-router"
CONFIG_DIR="${HOME}/.config/media-key-router"
KARABINER_CONFIG="${HOME}/.config/karabiner/karabiner.json"
ASSET_FILE="${HOME}/.config/karabiner/assets/complex_modifications/media-key-router.json"
RULE_DESCRIPTION="Smart F8 play/pause with configurable fallback"

if [ -f "$KARABINER_CONFIG" ] && command -v jq >/dev/null 2>&1; then
  BACKUP_FILE="${KARABINER_CONFIG}.media-key-router-uninstall-backup.$(date '+%Y%m%d-%H%M%S')"
  TEMP_FILE=$(mktemp "$(dirname "$KARABINER_CONFIG")/karabiner.json.XXXXXX")
  trap 'rm -f "$TEMP_FILE"' EXIT
  cp "$KARABINER_CONFIG" "$BACKUP_FILE"
  jq --arg description "$RULE_DESCRIPTION" '
    .profiles |= map(
      if .complex_modifications.rules then
        .complex_modifications.rules |= map(select(.description != $description))
      else . end
    )
  ' "$KARABINER_CONFIG" > "$TEMP_FILE"
  jq empty "$TEMP_FILE"
  chmod --reference="$KARABINER_CONFIG" "$TEMP_FILE" 2>/dev/null || chmod 600 "$TEMP_FILE"
  mv "$TEMP_FILE" "$KARABINER_CONFIG"
  trap - EXIT
  echo "Removed the Karabiner rule. Backup: $BACKUP_FILE"
fi

if [ -L "$BIN_LINK" ] && [ "$(readlink "$BIN_LINK")" = "${INSTALL_DIR}/media-key-router" ]; then
  rm -f "$BIN_LINK"
fi
rm -f "$ASSET_FILE"
rm -f "${INSTALL_DIR}/media-key-router"
rmdir "$INSTALL_DIR" 2>/dev/null || true
rm -f "${CONFIG_DIR}/config.json"
rmdir "$CONFIG_DIR" 2>/dev/null || true

echo "Media Key Router was removed. nowplaying-cli was left installed because it may be shared."
