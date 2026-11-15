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

check_out=$("$(dirname "$0")/check-outdated.sh" --format tsv) || skip "check-outdated.sh failed."

first_line=${check_out%%$'\n'*}
IFS=$'\t' read -r status code reason <<<"$first_line"

case "$status" in
  up_to_date)
    exit 0
    ;;
  skipped)
    [ "$code" = "no_apm_yml" ] && exit 0
    skip "$reason"
    ;;
  outdated)
    ;;
  *)
    skip "unexpected output from check-outdated.sh."
    ;;
esac

rows=""
notice_lines=""
while IFS=$'\t' read -r _ name current latest source; do
  [ -n "$name" ] || continue
  if [ -n "$source" ]; then
    row=$(printf '| %s | %s | %s | outdated | %s |' "$name" "$current" "$latest" "$source")
  else
    row=$(printf '| %s | %s | %s | outdated |' "$name" "$current" "$latest")
  fi
  notice_line=$(printf '  %s: %s → %s' "$name" "$current" "$latest")
  rows="${rows:+$rows$'\n'}$row"
  notice_lines="${notice_lines:+$notice_lines$'\n'}$notice_line"
done <<<"$check_out"

[ -n "$rows" ] || exit 0

notice="❗ outdated-skills: newer versions are available
$notice_lines"

emit "outdated-skills: apm.yml dependencies have a newer version than the one recorded (apm outdated):
$rows" "$(for_agent "$notice" "$rows")"
