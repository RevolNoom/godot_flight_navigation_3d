#!/usr/bin/env bash
#
# disable_claude_in_chrome.bash
#
# Disables the built-in "Claude in Chrome" browser integration by editing
# ~/.claude.json. This removes the mcp__claude-in-chrome__* tools and the
# large browser-automation system prompt block from your sessions.
#
# It:
#   1. Backs up ~/.claude.json (timestamped)
#   2. Sets claudeInChromeDefaultEnabled = false
#   3. Ensures "claude-in-chrome" is listed in disabledMcpServers for every
#      project (and the top level), so it stays off everywhere
#   4. Validates the result is still valid JSON before replacing the original
#
# Re-run is safe (idempotent). Requires: jq

set -euo pipefail

CONFIG="${HOME}/.claude.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required but not installed" >&2
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  echo "error: $CONFIG not found" >&2
  exit 1
fi

# 1. Backup
BACKUP="${CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
cp -p "$CONFIG" "$BACKUP"
echo "backup written: $BACKUP"

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

# 2 & 3. Turn off the default switch and add to disabledMcpServers everywhere.
jq '
  # main kill switch
  .claudeInChromeDefaultEnabled = false
  # stop auto-enable / upsell nudges if present
  | (if has("cachedChromeExtensionInstalled") then .cachedChromeExtensionInstalled = false else . end)

  # helper: given an object, ensure disabledMcpServers contains the name
  | .projects = (
      (.projects // {}) | with_entries(
        .value.disabledMcpServers = (
          ((.value.disabledMcpServers // []) + ["claude-in-chrome"]) | unique
        )
      )
    )
' "$CONFIG" > "$TMP"

# 4. Validate then swap in
if ! jq empty "$TMP" >/dev/null 2>&1; then
  echo "error: produced invalid JSON; original left untouched" >&2
  exit 1
fi

mv "$TMP" "$CONFIG"
trap - EXIT

echo "done: Claude in Chrome disabled in $CONFIG"
echo "restart Claude Code for the change to take effect."
