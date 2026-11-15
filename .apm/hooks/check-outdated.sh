#!/usr/bin/env bash
# Checks apm.yml dependencies against apm.lock.yaml via `apm outdated` and reports outdated entries.
# Standalone CLI with no dependency on CLAUDE_PROJECT_DIR or agent hook formatting.
# It only reports: apm.yml, apm.lock.yaml and the installation are not changed.

set -u

usage() {
  cat <<'EOF'
Usage: check-outdated.sh [--format plain|tsv|json] [-h|--help]

Check apm.yml dependencies in the current directory with `apm outdated`.

Options:
  -f, --format <fmt>  Output format: plain (default), tsv, or json
  -h, --help          Show this help message
EOF
}

format="plain"

while [ $# -gt 0 ]; do
  case "$1" in
    -f|--format)
      [ $# -ge 2 ] || { echo "check-outdated.sh: missing value for $1" >&2; exit 2; }
      format="$2"
      shift 2
      ;;
    --format=*)
      format="${1#--format=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "check-outdated.sh: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

case "$format" in
  plain|tsv|json) ;;
  *)
    echo "check-outdated.sh: unsupported format '$format' (expected plain, tsv, or json)" >&2
    exit 2
    ;;
esac

sanitize_field() {
  printf '%s' "$1" | tr '\r\n\t' '   ' | sed 's/^ *//; s/ *$//'
}

json_escape() {
  awk 'BEGIN { ORS="" } {
    gsub(/\\/, "\\\\")
    gsub(/"/, "\\\"")
    gsub(/\t/, "\\t")
    gsub(/\r/, "\\r")
    if (NR > 1) printf "\\n"
    printf "%s", $0
  }' <<<"$1"
}

emit_result() {
  local status="$1" code="$2" reason="$3" rows="${4:-}"
  case "$format" in
    plain)
      case "$status" in
        skipped)
          printf 'skipped (%s): %s\n' "$code" "$reason"
          ;;
        up_to_date)
          printf 'up-to-date: all apm.yml dependencies are up to date.\n'
          ;;
        outdated)
          printf 'outdated: newer versions are available\n'
          while IFS=$'\t' read -r _ name current latest _source; do
            [ -n "$name" ] || continue
            printf '  %s: %s → %s\n' "$name" "$current" "$latest"
          done <<<"$rows"
          ;;
      esac
      ;;
    tsv)
      case "$status" in
        skipped)
          printf 'skipped\t%s\t%s\n' "$code" "$reason"
          ;;
        up_to_date)
          printf 'up_to_date\n'
          ;;
        outdated)
          printf '%s\n' "$rows"
          ;;
      esac
      ;;
    json)
      if command -v jq >/dev/null 2>&1; then
        jq -R -s \
          --arg status "$status" \
          --arg code "$code" \
          --arg reason "$reason" '
          (if $code == "" then null else $code end) as $c
          | (if $reason == "" then null else $reason end) as $r
          | split("\n")
          | map(select(length > 0))
          | map(split("\t") | {
              name: .[1],
              current: .[2],
              latest: .[3],
              source: (if (.[4] // "") == "" then null else .[4] end)
            })
          | {status: $status, code: $c, reason: $r, outdated: .}
        ' <<<"$rows"
      else
        local code_json reason_json first=1 source_json
        code_json=$([ -n "$code" ] && printf '"%s"' "$(json_escape "$code")" || printf 'null')
        reason_json=$([ -n "$reason" ] && printf '"%s"' "$(json_escape "$reason")" || printf 'null')
        printf '{"status":"%s","code":%s,"reason":%s,"outdated":[' \
          "$(json_escape "$status")" "$code_json" "$reason_json"
        while IFS=$'\t' read -r _ name current latest source; do
          [ -n "$name" ] || continue
          [ "$first" -eq 1 ] || printf ','
          first=0
          source_json=$([ -n "$source" ] && printf '"%s"' "$(json_escape "$source")" || printf 'null')
          printf '{"name":"%s","current":"%s","latest":"%s","source":%s}' \
            "$(json_escape "$name")" \
            "$(json_escape "$current")" \
            "$(json_escape "$latest")" \
            "$source_json"
        done <<<"$rows"
        printf ']}\n'
      fi
      ;;
  esac
  exit 0
}

emit_skip() {
  emit_result "skipped" "$1" "$(sanitize_field "$2")"
}

[ -f apm.yml ] || emit_skip "no_apm_yml" "no apm.yml in current directory."
[ -f apm.lock.yaml ] || emit_skip "no_lockfile" "no apm.lock.yaml, and apm outdated compares versions against it."
command -v apm >/dev/null 2>&1 || emit_skip "no_apm" "apm is not in PATH."

errors=$(mktemp) || emit_skip "mktemp_failed" "could not create a temporary file."
trap 'rm -f "$errors"' EXIT

# COLUMNS=250: without it apm truncates names in the table to the terminal width.
# stderr goes to a separate file: its lines must not end up in the table parsing.
table=$(COLUMNS=250 apm outdated 2>"$errors")
rc=$?
if [ "$rc" -ne 0 ]; then
  err_summary=$(head -n 5 "$errors")
  [ -n "$err_summary" ] || err_summary="exit code $rc"
  emit_skip "apm_failed" "apm outdated failed: $err_summary"
fi

# Parse table rows whose 4th cell (status) is exactly "outdated"; Source column (5th cell) is optional.
# Normalize Unicode box-drawing borders (│, ┃) to "|" first so byte-oriented awks (mawk) split cleanly.
parsed_tsv=$(awk '
  function trim(s) {
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
    return s
  }
  {
    gsub(/│|┃/, "|")
    n = split($0, cols, "|")
    if (n >= 5 && trim(cols[5]) == "outdated") {
      name = trim(cols[2])
      current = trim(cols[3])
      latest = trim(cols[4])
      source = (n >= 6) ? trim(cols[6]) : ""
      printf "outdated\t%s\t%s\t%s\t%s\n", name, current, latest, source
    }
  }
' <<<"$table")

[ -n "$parsed_tsv" ] || emit_result "up_to_date" "" ""
emit_result "outdated" "" "" "$parsed_tsv"
