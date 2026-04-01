#!/usr/bin/env bash
# Friction ledger query tool — wraps jq for common queries
# Usage: query.sh <command> [args]

set -euo pipefail

LEDGER="${HOME}/.claude/friction/friction.jsonl"

if [ ! -f "$LEDGER" ]; then
  echo "No ledger found at $LEDGER" >&2
  exit 1
fi

jq_query() { jq -s "$1" "$LEDGER"; }

usage() {
  cat <<'EOF'
Usage: query.sh <command> [args]

Commands:
  domain <tag> [--last N]     Friction entries matching domain tag (default: last 90 days)
  failing [--min N]           Constraints that have failed N+ times (default: 2)
  chain <friction-id>         Follow full recurrence chain from a friction ID
  recent [--last N]           Most recent N entries (default: 10)
  stats                       Summary statistics
  search <pattern>            Regex search across descriptions and causes
  types                       Count by friction type
  domains                     Count by domain tag
  trend <tag> [--window N]    Friction count per week for domain (default: 12 weeks)
  unconstrained [--min N]     Recurring patterns with no constraint (default: 2+ occurrences)
  stale [--days N]            Constraints with no friction in N+ days (default: 60)
  lifecycle                   Entries by status (pipeline bottlenecks)

Examples:
  query.sh domain meta-api --last 30
  query.sh failing --min 3
  query.sh chain f-20260324-001
  query.sh recent --last 20
  query.sh search "audience"
  query.sh trend harness-engineering --window 8
EOF
}

# Portable date arithmetic (macOS + Linux)
date_ago_days() {
  date -v-"${1}"d +%Y-%m-%d 2>/dev/null || date -d "-${1} days" +%Y-%m-%d
}
date_ago_weeks() {
  date -v-"${1}"w +%Y-%m-%d 2>/dev/null || date -d "-${1} weeks" +%Y-%m-%d
}

cmd_domain() {
  local tag="${1:?Usage: query.sh domain <tag> [--last N]}"
  shift
  local days=90
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --last) days="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  local cutoff
  cutoff=$(date_ago_days "$days")
  jq_query "
    [.[] | select((.domains // [])[] == \"$tag\" and .date >= \"$cutoff\")]
    | sort_by(.date) | reverse
  "
}

cmd_failing() {
  local min=2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --min) min="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  jq_query "
    [.[] | select(.constraint_failed == 1 and .constraint_existed != null)]
    | group_by(.constraint_existed)
    | map({
        constraint_name: .[0].constraint_existed,
        failure_count: length,
        friction_ids: [.[].id] | join(\", \")
      })
    | [.[] | select(.failure_count >= $min)]
    | sort_by(.failure_count) | reverse
  "
}

cmd_chain() {
  local id="${1:?Usage: query.sh chain <friction-id>}"
  jq_query "
    . as \$all |
    (\$all | map({(.id): .}) | add) as \$byid |
    (\"$id\" | until(
      . as \$cur | (\$byid[\$cur].recurrence_of == null);
      \$byid[.].recurrence_of
    )) as \$root |
    [
      def descendants(\$rid):
        (\$all[] | select(.id == \$rid)),
        (\$all[] | select(.recurrence_of == \$rid) | descendants(.id));
      descendants(\$root)
    ] | unique_by(.id) | sort_by(.date)
  "
}

cmd_recent() {
  local count=10
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --last) count="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  jq_query "sort_by(.date, .id) | reverse | .[:$count]"
}

cmd_stats() {
  jq_query '
    {
      total: length,
      constraint_failures: [.[] | select(.constraint_failed == 1)] | length,
      with_prescriptions: [.[] | select(
        .prescribed_advisory != null or
        .prescribed_structural != null or
        .prescribed_mechanical != null
      )] | length,
      by_status: (group_by(.status) | map({status: .[0].status, count: length})),
      by_type: (group_by(.type) | map({type: .[0].type, count: length}) | sort_by(.count) | reverse),
      by_domain: ([.[].domains[]] | group_by(.) | map({domain: .[0], count: length}) | sort_by(.count) | reverse)
    }
  '
}

cmd_search() {
  local pattern="${1:?Usage: query.sh search <pattern>}"
  jq_query "
    [.[] | select(
      (.description | test(\"$pattern\"; \"i\")) or
      (.root_cause // \"\" | test(\"$pattern\"; \"i\")) or
      (.deep_cause // \"\" | test(\"$pattern\"; \"i\"))
    )]
    | sort_by(.date) | reverse
  "
}

cmd_types() {
  jq_query 'group_by(.type) | map({type: .[0].type, count: length}) | sort_by(.count) | reverse'
}

cmd_domains() {
  jq_query '
    [.[].domains[]] | group_by(.) | map({domain: .[0], count: length})
    | sort_by(.count) | reverse
  '
}

cmd_trend() {
  local tag="${1:?Usage: query.sh trend <tag> [--window N]}"
  shift
  local weeks=12
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --window) weeks="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  local cutoff
  cutoff=$(date_ago_weeks "$weeks")
  jq_query "
    [.[] | select((.domains // [])[] == \"$tag\" and .date >= \"$cutoff\")]
    | group_by(.date[:4] + \"-W\" + (.date | strptime(\"%Y-%m-%d\") | strftime(\"%W\")))
    | map({week: .[0].date[:4] + \"-W\" + (.[0].date | strptime(\"%Y-%m-%d\") | strftime(\"%W\")), count: length})
    | sort_by(.week)
  "
}

cmd_unconstrained() {
  local min=2
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --min) min="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  jq_query "
    [.[] | select(.constraint_existed == null)]
    | group_by(.type + \"|||\" + (.deep_cause // \"\"))
    | map({
        type: .[0].type,
        deep_cause: .[0].deep_cause,
        occurrences: length,
        friction_ids: [.[].id] | join(\", \")
      })
    | [.[] | select(.occurrences >= $min)]
    | sort_by(.occurrences) | reverse
  "
}

cmd_stale() {
  local days=60
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --days) days="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  local cutoff
  cutoff=$(date_ago_days "$days")
  jq_query "
    [.[] | select(.constraint_existed != null)]
    | group_by(.constraint_existed)
    | map({
        constraint_name: .[0].constraint_existed,
        last_seen: ([.[].date] | max),
        total_references: length
      })
    | [.[] | select(.last_seen < \"$cutoff\")]
    | sort_by(.last_seen)
  "
}

cmd_lifecycle() {
  jq_query '
    group_by(.status)
    | map({
        status: .[0].status,
        count: length,
        ids: [.[].id] | join(", ")
      })
    | sort_by(
        if .status == "captured" then 1
        elif .status == "analyzed" then 2
        elif .status == "prescribed" then 3
        elif .status == "implemented" then 4
        elif .status == "verified" then 5
        else 6 end
      )
  '
}

case "${1:-}" in
  domain)        shift; cmd_domain "$@" ;;
  failing)       shift; cmd_failing "$@" ;;
  chain)         shift; cmd_chain "$@" ;;
  recent)        shift; cmd_recent "$@" ;;
  stats)         shift; cmd_stats "$@" ;;
  search)        shift; cmd_search "$@" ;;
  types)         shift; cmd_types "$@" ;;
  domains)       shift; cmd_domains "$@" ;;
  trend)         shift; cmd_trend "$@" ;;
  unconstrained) shift; cmd_unconstrained "$@" ;;
  stale)         shift; cmd_stale "$@" ;;
  lifecycle)     shift; cmd_lifecycle "$@" ;;
  help|-h|--help) usage ;;
  *)             usage; exit 1 ;;
esac
