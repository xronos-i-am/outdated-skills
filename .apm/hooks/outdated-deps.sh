#!/usr/bin/env bash
# SessionStart hook: reports the apm.yml dependencies that have a newer version than the one recorded.
# It only reports: apm.yml, apm.lock.yaml and the installation are not changed, apm install is not run.
# apm outdated goes to the network and takes seconds, and a synchronous SessionStart hook blocks the start
# of the session, so outdated-deps.json runs the hook with "async": true.
# Claude Code gives the output of an async hook only to the agent, on the next turn, and does not show it
# to the person: the agent is told to start its first reply with a ready-made text, verbatim.
# emit <plain text> [<text for the agent>]: in Claude Code (CLAUDE_PROJECT_DIR is set) it prints JSON
# with additionalContext; elsewhere, or without jq, it prints the plain text.

emit() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && command -v jq >/dev/null 2>&1; then
    jq -n --arg message "${2:-$1}" \
      '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $message}}'
  else
    printf '%s\n' "$1"
  fi
}

# for_agent <text for the person> [<apm outdated rows>]
for_agent() {
  printf '%s\n\n%s\n' "Start your first reply with the text below, verbatim, before anything else: the person does not see this message." "$1"
  [ -z "${2:-}" ] || printf '\nThe apm outdated rows:\n%s\n' "$2"
}

skip() {
  local notice="❗ outdated-skills: dependency check not done — $1"
  emit "$notice" "$(for_agent "$notice")"
  exit 0
}

[ -f apm.yml ] || exit 0
[ -f apm.lock.yaml ] || skip "no apm.lock.yaml, and apm outdated compares versions against it."
command -v apm >/dev/null 2>&1 || skip "apm is not in PATH."

# COLUMNS=250: without it apm truncates names in the table to the terminal width.
# stderr goes to a separate file: its lines must not end up in the table parsing
errors=$(mktemp) || skip "could not create a temporary file."
trap 'rm -f "$errors"' EXIT
table=$(COLUMNS=250 apm outdated 2>"$errors") || skip "apm outdated failed: $(head -n 5 "$errors")"

# The status is a table cell that is exactly "outdated"; other columns, such as Source, may follow it
rows=$(grep -E '[|│┃][[:space:]]*outdated[[:space:]]*[|│┃]' <<<"$table")
[ -n "$rows" ] || exit 0

# Table row "| name | current | latest | outdated | source |" -> "  name: current → latest"
notice="❗ outdated-skills: newer versions are available
$(awk -F'|' '{ for (i = 2; i <= 4; i++) gsub(/^ +| +$/, "", $i); printf "  %s: %s → %s\n", $2, $3, $4 }' <<<"$rows")"

emit "outdated-skills: apm.yml dependencies have a newer version than the one recorded (apm outdated):
$rows" "$(for_agent "$notice" "$rows")"
