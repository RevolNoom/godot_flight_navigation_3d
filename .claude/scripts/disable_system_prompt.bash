#!/usr/bin/env bash
#
# disable_system_prompt.bash
#
# Adds an alias to ~/.bashrc so `claude` runs with an empty system prompt:
#   alias claude='claude --system-prompt=""'
#
# Idempotent: the alias block is only added once.
#
set -euo pipefail

RC="${HOME}/.bashrc"
MARKER="# >>> claude empty system prompt >>>"
END_MARKER="# <<< claude empty system prompt <<<"

if [[ -f "${RC}" ]] && grep -qF "${MARKER}" "${RC}"; then
  echo "Alias block already present in ${RC}; nothing to do."
  exit 0
fi

cat >> "${RC}" <<'EOF'

# >>> claude empty system prompt >>>
alias claude='claude --system-prompt=""'
# <<< claude empty system prompt <<<
EOF

echo "Added alias to ${RC}."
echo "Run 'source ${RC}' or open a new shell to apply it."
