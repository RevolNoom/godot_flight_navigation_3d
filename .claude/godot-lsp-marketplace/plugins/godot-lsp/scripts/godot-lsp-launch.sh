#!/usr/bin/env bash
#
# Launches the GDScript LSP bridge with machine-independent paths.
#
# Claude Code substitutes ${CLAUDE_PROJECT_DIR} in the manifest, so the project
# path needs no hardcoding. The Godot binary is the part that genuinely varies
# between machines (versioned filenames like godot4.7.1.x86_64, flatpak, distro
# packages), so it is discovered at runtime here rather than baked into a
# committed config file.
#
# Resolution order for the Godot binary:
#   1. $GODOT_PATH, if set and executable
#   2. common command names on PATH
#   3. versioned binaries in common install dirs, highest version first
#
# Usage: godot-lsp-launch.sh [extra args passed through to godot-lsp-bridge]

set -euo pipefail

readonly BRIDGE_BIN="godot-lsp-bridge"
readonly PORT="${GODOT_LSP_PORT:-6005}"

log() { printf '[godot-lsp-launch] %s\n' "$1" >&2; }
die() { printf '[godot-lsp-launch] ERROR: %s\n' "$1" >&2; exit 1; }

# --- Project directory ------------------------------------------------------

# Claude Code exports CLAUDE_PROJECT_DIR to LSP subprocesses. Fall back to the
# plugin's own location only if it is somehow absent.
project_dir="${CLAUDE_PROJECT_DIR:-}"
if [[ -z "${project_dir}" ]]; then
  project_dir="$(pwd)"
  log "CLAUDE_PROJECT_DIR unset; falling back to cwd: ${project_dir}"
fi

[[ -f "${project_dir}/project.godot" ]] \
  || log "warning: no project.godot in ${project_dir}; Godot may fail to open it"

# --- Godot binary -----------------------------------------------------------

find_godot() {
  # 1. Explicit override.
  if [[ -n "${GODOT_PATH:-}" ]]; then
    if [[ -x "${GODOT_PATH}" ]]; then
      printf '%s\n' "${GODOT_PATH}"
      return 0
    fi
    die "GODOT_PATH is set to '${GODOT_PATH}' but that is not executable."
  fi

  # 2. Plain names on PATH.
  local name
  for name in godot godot4 godot-4 Godot; do
    if command -v "${name}" >/dev/null 2>&1; then
      command -v "${name}"
      return 0
    fi
  done

  # 3. Versioned binaries in common install dirs. Sort by version, newest
  #    first, so godot4.7.1 wins over godot4.2.
  local dir candidate
  for dir in "${HOME}/.local/bin" /usr/local/bin /usr/bin /opt/godot; do
    [[ -d "${dir}" ]] || continue
    candidate="$(find "${dir}" -maxdepth 1 -type f -executable \
                   \( -name 'godot*' -o -name 'Godot*' \) 2>/dev/null \
                 | grep -v -- '-lsp-' \
                 | sort -V -r \
                 | head -n 1)"
    if [[ -n "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

godot_bin="$(find_godot)" || die \
  "No Godot binary found. Set GODOT_PATH to your Godot executable, or put it on PATH.
  Searched: \$GODOT_PATH, PATH (godot, godot4, godot-4, Godot),
  and ~/.local/bin /usr/local/bin /usr/bin /opt/godot"

log "godot:   ${godot_bin}"
log "project: ${project_dir}"
log "port:    ${PORT}"

# Report what would be used and exit, without starting a server. Used by
# setup-godot-lsp.sh so its summary can never drift from this logic.
if [[ -n "${GODOT_LSP_RESOLVE_ONLY:-}" ]]; then
  exit 0
fi

command -v "${BRIDGE_BIN}" >/dev/null 2>&1 || die \
  "${BRIDGE_BIN} not found on PATH. Run: npm install -g opencode-godot-lsp"

exec "${BRIDGE_BIN}" \
  --port "${PORT}" \
  --godot "${godot_bin}" \
  --project "${project_dir}" \
  "$@"
