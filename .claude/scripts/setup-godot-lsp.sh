#!/usr/bin/env bash
#
# Sets up GDScript LSP for Claude Code.
#
# Godot's LSP is TCP-only and lives inside the editor process. Claude Code
# spawns language servers over stdio. This wires up the community
# opencode-godot-lsp bridge between the two, then registers a local marketplace
# plugin pointing at it.
#
# The bridge auto-launches a headless editor when none is listening on 6005,
# so keeping the GUI editor open is optional.
#
# Assumes Node.js 18+ is already on PATH.
#
# Usage: .claude/scripts/setup-godot-lsp.sh

set -euo pipefail

readonly BRIDGE_PKG="opencode-godot-lsp"
readonly BRIDGE_BIN="godot-lsp-bridge"
readonly MIN_NODE_MAJOR=18

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPO_ROOT
readonly MARKETPLACE_DIR="${REPO_ROOT}/.claude/godot-lsp-marketplace"
readonly SETTINGS="${HOME}/.claude/settings.json"

info()  { printf '\033[0;36m==>\033[0m %s\n' "$1"; }
ok()    { printf '\033[0;32m  ok\033[0m %s\n' "$1"; }
warn()  { printf '\033[0;33m  !!\033[0m %s\n' "$1"; }
die()   { printf '\033[0;31mERROR:\033[0m %s\n' "$1" >&2; exit 1; }

# --- 1. Prerequisites -------------------------------------------------------

info "Checking prerequisites"

command -v node >/dev/null 2>&1 || die \
  "Node.js not found on PATH. ${BRIDGE_PKG} is a Node package and needs Node ${MIN_NODE_MAJOR}+.
  Install it, then re-run this script."

command -v npm >/dev/null 2>&1 || die \
  "npm not found on PATH. It normally ships with Node.js; check your install."

node_major="$(node --version | sed 's/^v\([0-9]*\).*/\1/')"
if [[ "${node_major}" -lt "${MIN_NODE_MAJOR}" ]]; then
  die "Node $(node --version) is too old; ${BRIDGE_PKG} needs ${MIN_NODE_MAJOR}+."
fi
ok "Node $(node --version)"

command -v claude >/dev/null 2>&1 || die "claude CLI not found on PATH."
ok "claude $(claude --version)"

command -v python3 >/dev/null 2>&1 || die "python3 not found; needed to edit settings.json safely."

[[ -d "${MARKETPLACE_DIR}" ]] || die \
  "Local marketplace missing at ${MARKETPLACE_DIR}
  Expected it to be committed alongside this script."

# --- 2. Install the bridge --------------------------------------------------

info "Installing ${BRIDGE_PKG}"

if command -v "${BRIDGE_BIN}" >/dev/null 2>&1; then
  ok "already installed at $(command -v "${BRIDGE_BIN}")"
else
  npm install -g "${BRIDGE_PKG}"
  command -v "${BRIDGE_BIN}" >/dev/null 2>&1 || die \
    "${BRIDGE_BIN} still not on PATH after install.
  npm's global bin dir is probably not on PATH. Check: npm bin -g"
  ok "installed at $(command -v "${BRIDGE_BIN}")"
fi

# --- 3. Enable the LSP tool -------------------------------------------------

info "Enabling ENABLE_LSP_TOOL in ${SETTINGS}"

python3 - "$SETTINGS" <<'PY'
import json, os, shutil, sys

path = sys.argv[1]
os.makedirs(os.path.dirname(path), exist_ok=True)

settings = {}
if os.path.exists(path):
    shutil.copy2(path, path + ".bak")
    with open(path) as f:
        text = f.read().strip()
    if text:
        settings = json.loads(text)

env = settings.setdefault("env", {})
if env.get("ENABLE_LSP_TOOL") == "1":
    print("  ok already enabled")
else:
    env["ENABLE_LSP_TOOL"] = "1"
    print("  ok set ENABLE_LSP_TOOL=1")

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PY

# --- 4. Register marketplace and install plugin -----------------------------

info "Registering local marketplace"

claude plugin validate "${MARKETPLACE_DIR}" \
  || die "Marketplace manifest failed validation."

if claude plugin marketplace list 2>/dev/null | grep -q 'godot-lsp-local'; then
  claude plugin marketplace update godot-lsp-local
  ok "marketplace updated"
else
  claude plugin marketplace add "${MARKETPLACE_DIR}"
  ok "marketplace added"
fi

info "Installing godot-lsp plugin"
if claude plugin list 2>/dev/null | grep -q 'godot-lsp'; then
  # Do NOT skip here. The plugin is cached per-version under
  # ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/, so an already
  # installed plugin keeps serving the OLD cached files -- including a stale
  # scripts/ dir that ${CLAUDE_PLUGIN_ROOT} would resolve to -- until it is
  # explicitly updated. Bumping "version" in marketplace.json is what triggers
  # a new cache directory.
  claude plugin update godot-lsp@godot-lsp-local
  ok "updated to the manifest version"
else
  claude plugin install godot-lsp@godot-lsp-local
  ok "installed"
fi

# --- 5. Report --------------------------------------------------------------

# Ask the wrapper itself what it resolves, so this report can never drift from
# the logic that actually runs.
readonly LAUNCHER="${MARKETPLACE_DIR}/plugins/godot-lsp/scripts/godot-lsp-launch.sh"

godot_bin="$(CLAUDE_PROJECT_DIR="${REPO_ROOT}" GODOT_LSP_RESOLVE_ONLY=1 \
             bash "${LAUNCHER}" 2>&1 </dev/null \
             | sed -n 's/^\[godot-lsp-launch\] godot:[[:space:]]*//p' | head -n 1)"

if [[ -z "${godot_bin}" ]]; then
  warn "could not auto-discover a Godot binary; set GODOT_PATH before use"
  godot_bin="<not found — set GODOT_PATH>"
else
  ok "godot resolved to ${godot_bin}"
fi

cat <<EOF

$(printf '\033[0;32mSetup complete.\033[0m')

One thing is required for GDScript LSP to actually respond:

  * Restart Claude Code completely. LSP servers initialize at startup,
    so a running session will not pick this up.

You no longer need to keep the Godot editor open. If nothing is listening
on port 6005, ${BRIDGE_BIN} launches its own editor headlessly. If a GUI
editor IS running on 6005, the bridge attaches to it instead of spawning
a second instance.

The manifest holds no machine-specific paths, so it syncs between machines
unchanged. scripts/godot-lsp-launch.sh resolves the project directory from
\${CLAUDE_PROJECT_DIR} and discovers the Godot binary at runtime.

Resolved on this machine:

    godot:   ${godot_bin}
    project: ${REPO_ROOT}

If discovery picks the wrong binary, export GODOT_PATH — do not edit the
manifest.

To verify the bridge end to end:

    CLAUDE_PROJECT_DIR=${REPO_ROOT} bash \\
      ${MARKETPLACE_DIR}/plugins/godot-lsp/scripts/godot-lsp-launch.sh
    # expect: Connected to Godot LSP on 127.0.0.1:6005
EOF
