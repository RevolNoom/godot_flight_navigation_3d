#!/usr/bin/env bash
#
# deny_system_tools.bash
#
# Adds a set of system/host tools to permissions.deny in ~/.claude/settings.json.
# Idempotent: existing deny entries are preserved and the result is deduplicated.
#
set -euo pipefail

SETTINGS="${HOME}/.claude/settings.json"

# "Cron*" is expanded to the concrete tool names, since Claude Code deny rules
# match exact tool names rather than glob patterns.
TOOLS=(
  Artifact
  CronCreate
  CronDelete
  CronList
  EnterPlanMode
  ExitPlanMode
  Monitor
  NotebookEdit
  PowerShell
  PushNotification
  RemoteTrigger
  ReportFindings
  ScheduleWakeup
  SendUserFile
  ShareOnboardingGuide
  Workflow
)

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required but not found in PATH" >&2
  exit 1
fi

if [[ ! -f "${SETTINGS}" ]]; then
  echo "error: settings file not found: ${SETTINGS}" >&2
  exit 1
fi

# Back up before modifying.
cp "${SETTINGS}" "${SETTINGS}.bak"

new_tools="$(printf '%s\n' "${TOOLS[@]}" | jq -R . | jq -s .)"

tmp="$(mktemp)"
jq --argjson new "${new_tools}" \
  '.permissions = (.permissions // {})
   | .permissions.deny = (((.permissions.deny // []) + $new) | unique)' \
  "${SETTINGS}" \
  > "${tmp}"

mv "${tmp}" "${SETTINGS}"

echo "Updated ${SETTINGS} (backup at ${SETTINGS}.bak)"
echo "permissions.deny now:"
jq '.permissions.deny' "${SETTINGS}"
