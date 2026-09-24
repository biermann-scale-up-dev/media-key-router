#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ROUTER="${ROOT_DIR}/bin/media-key-router"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/media-key-router-tests.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

MOCK_BIN="${TEST_DIR}/bin"
CONFIG_DIR="${TEST_DIR}/config"
STATE_DIR="${TEST_DIR}/state"
CALLS_FILE="${TEST_DIR}/calls"
FAKE_APP="${TEST_DIR}/Spotify.app"
mkdir -p "$MOCK_BIN" "$CONFIG_DIR" "$STATE_DIR" "${FAKE_APP}/Contents"
: > "$CALLS_FILE"

cat > "${FAKE_APP}/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.spotify.client</string>
  <key>CFBundleDisplayName</key><string>Spotify</string>
</dict></plist>
EOF

cat > "${MOCK_BIN}/nowplaying-cli" <<'EOF'
#!/bin/bash
echo "nowplaying:$*" >> "$MOCK_CALLS_FILE"
if [ "$1" = "get" ]; then
  printf '%s\n' "$MOCK_SESSION_JSON"
fi
EOF

cat > "${MOCK_BIN}/open" <<'EOF'
#!/bin/bash
echo "open:$*" >> "$MOCK_CALLS_FILE"
EOF

cat > "${MOCK_BIN}/osascript" <<'EOF'
#!/bin/bash
echo "osascript:$*" >> "$MOCK_CALLS_FILE"
exit "${MOCK_OSASCRIPT_STATUS:-0}"
EOF

cat > "${MOCK_BIN}/pgrep" <<'EOF'
#!/bin/bash
echo "pgrep:$*" >> "$MOCK_CALLS_FILE"
exit "${MOCK_PGREP_STATUS:-1}"
EOF
chmod +x "${MOCK_BIN}"/*

export MOCK_CALLS_FILE="$CALLS_FILE"
export MEDIA_KEY_ROUTER_CONFIG_DIR="$CONFIG_DIR"
export MEDIA_KEY_ROUTER_STATE_DIR="$STATE_DIR"
export MEDIA_KEY_ROUTER_LOG_FILE="${TEST_DIR}/router.log"
export MEDIA_KEY_ROUTER_NOWPLAYING_BIN="${MOCK_BIN}/nowplaying-cli"
export MEDIA_KEY_ROUTER_OPEN_BIN="${MOCK_BIN}/open"
export MEDIA_KEY_ROUTER_OSASCRIPT_BIN="${MOCK_BIN}/osascript"
export MEDIA_KEY_ROUTER_PGREP_BIN="${MOCK_BIN}/pgrep"
export MEDIA_KEY_ROUTER_DEBOUNCE_MS=0

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  grep -Fq "$1" "$CALLS_FILE" || fail "expected call containing: $1"
}

assert_not_contains() {
  if grep -Fq "$1" "$CALLS_FILE"; then
    fail "unexpected call containing: $1"
  fi
}

reset_calls() {
  : > "$CALLS_FILE"
}

"$ROUTER" default "$FAKE_APP" >/dev/null

MOCK_SESSION_JSON='{"playbackRate":1,"title":"Track","clientBundleIdentifier":"com.spotify.client","uniqueIdentifier":"1"}'
export MOCK_SESSION_JSON
reset_calls
"$ROUTER" toggle
assert_contains "nowplaying:togglePlayPause"
assert_not_contains "open:"

MOCK_SESSION_JSON='{"playbackRate":0,"title":"Paused video","clientBundleIdentifier":"com.google.Chrome","uniqueIdentifier":"2"}'
export MOCK_SESSION_JSON
reset_calls
"$ROUTER" toggle
assert_contains "nowplaying:togglePlayPause"
assert_not_contains "open:"

MOCK_SESSION_JSON='{"playbackRate":null,"title":null,"clientBundleIdentifier":null,"uniqueIdentifier":null}'
export MOCK_SESSION_JSON
reset_calls
"$ROUTER" toggle
assert_contains "open:-gj ${FAKE_APP}"
assert_contains "osascript:-e tell application id \"com.spotify.client\" to play"
assert_not_contains "nowplaying:togglePlayPause"

MOCK_SESSION_JSON='{"playbackRate":0,"title":"Stale","clientBundleIdentifier":"com.apple.Music","uniqueIdentifier":"3"}'
MOCK_PGREP_STATUS=1
export MOCK_SESSION_JSON MOCK_PGREP_STATUS
reset_calls
"$ROUTER" toggle
assert_contains "pgrep:-x Music"
assert_contains "open:-gj ${FAKE_APP}"
assert_not_contains "nowplaying:togglePlayPause"

MOCK_PGREP_STATUS=0
export MOCK_PGREP_STATUS
reset_calls
"$ROUTER" toggle
assert_contains "pgrep:-x Music"
assert_contains "nowplaying:togglePlayPause"
assert_not_contains "open:"

MEDIA_KEY_ROUTER_DEBOUNCE_MS=10000
export MEDIA_KEY_ROUTER_DEBOUNCE_MS
rm -f "${STATE_DIR}/last-toggle-ms"
reset_calls
"$ROUTER" toggle
"$ROUTER" toggle
LINES=$(wc -l < "$CALLS_FILE" | tr -d ' ')
[ "$LINES" -eq 3 ] || fail "debounce should allow only one query and toggle; got $LINES calls"

STATUS_OUTPUT=$(MEDIA_KEY_ROUTER_NOWPLAYING_BIN="${TEST_DIR}/missing-nowplaying-cli" "$ROUTER" status 2>&1 || true)
printf '%s' "$STATUS_OUTPUT" | grep -Fq 'nowplaying-cli: MISSING' \
  || fail "status should report a missing nowplaying-cli"

echo "All media-key-router tests passed."
