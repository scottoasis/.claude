#!/usr/bin/env bash
# Friction ledger query tool — wraps sqlite3 for common queries
# Usage: query.sh <command> [args]

set -euo pipefail

DB="${HOME}/.claude/friction/friction.db"

if [ ! -f "$DB" ]; then
  echo "No database found at $DB" >&2
  exit 1
fi

sql_json() { sqlite3 -json "$DB" "$1"; }
sql_raw() { sqlite3 "$DB" "$1"; }

usage() {
  cat <<'EOF'
Usage: query.sh <command> [args]

Commands:
  domain <tag> [--last N]     Friction entries matching domain tag (default: last 90 days)
  failing [--min N]           Constraints that have failed N+ times (default: 2)
  chain <friction-id>         Follow full recurrence chain from a friction ID
  recent [--last N]           Most recent N entries (default: 10)
  stats                       Summary statistics
  search <pattern>            Full-text search across descriptions and causes
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
  sql_json "
    SELECT f.*
    FROM friction f
    JOIN friction_domain fd ON f.id = fd.friction_id
    WHERE fd.domain = '${tag}'
      AND f.date >= date('now', '-${days} days')
    ORDER BY f.date DESC;
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
  sql_json "
    SELECT constraint_existed AS constraint_name,
           COUNT(*) AS failure_count,
           GROUP_CONCAT(id, ', ') AS friction_ids
    FROM friction
    WHERE constraint_failed = 1
      AND constraint_existed IS NOT NULL
    GROUP BY constraint_existed
    HAVING COUNT(*) >= ${min}
    ORDER BY failure_count DESC;
  "
}

cmd_chain() {
  local id="${1:?Usage: query.sh chain <friction-id>}"
  sql_json "
    WITH RECURSIVE
      -- Walk UP to find the root
      ancestors AS (
        SELECT * FROM friction WHERE id = '${id}'
        UNION ALL
        SELECT f.* FROM friction f
        JOIN ancestors a ON f.id = a.recurrence_of
      ),
      -- Find the root ID (the one with no recurrence_of or whose recurrence_of isn't in the chain)
      root AS (
        SELECT id FROM ancestors WHERE recurrence_of IS NULL
        UNION
        SELECT a.id FROM ancestors a WHERE a.recurrence_of NOT IN (SELECT id FROM ancestors)
        LIMIT 1
      ),
      -- Walk DOWN from root
      descendants AS (
        SELECT * FROM friction WHERE id IN (SELECT id FROM root)
        UNION ALL
        SELECT f.* FROM friction f
        JOIN descendants d ON f.recurrence_of = d.id
      )
    SELECT DISTINCT * FROM descendants ORDER BY date;
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
  sql_json "SELECT * FROM friction ORDER BY date DESC, id DESC LIMIT ${count};"
}

cmd_stats() {
  sql_json "
    SELECT
      (SELECT COUNT(*) FROM friction) AS total,
      (SELECT COUNT(*) FROM friction WHERE constraint_failed = 1) AS constraint_failures,
      (SELECT COUNT(*) FROM friction
       WHERE prescribed_advisory IS NOT NULL
          OR prescribed_structural IS NOT NULL
          OR prescribed_mechanical IS NOT NULL) AS with_prescriptions;
  "
  echo "---"
  sql_json "SELECT status, COUNT(*) AS count FROM friction GROUP BY status;"
  echo "---"
  sql_json "SELECT type, COUNT(*) AS count FROM friction GROUP BY type ORDER BY count DESC;"
  echo "---"
  sql_json "
    SELECT fd.domain, COUNT(*) AS count
    FROM friction_domain fd
    GROUP BY fd.domain ORDER BY count DESC;
  "
}

cmd_search() {
  local pattern="${1:?Usage: query.sh search <pattern>}"
  sql_json "
    SELECT f.*
    FROM friction f
    JOIN friction_fts fts ON f.rowid = fts.rowid
    WHERE friction_fts MATCH '${pattern}'
    ORDER BY rank;
  "
}

cmd_types() {
  sql_json "SELECT type, COUNT(*) AS count FROM friction GROUP BY type ORDER BY count DESC;"
}

cmd_domains() {
  sql_json "
    SELECT domain, COUNT(*) AS count
    FROM friction_domain GROUP BY domain ORDER BY count DESC;
  "
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
  sql_json "
    SELECT strftime('%Y-W%W', f.date) AS week,
           COUNT(*) AS count
    FROM friction f
    JOIN friction_domain fd ON f.id = fd.friction_id
    WHERE fd.domain = '${tag}'
      AND f.date >= date('now', '-${weeks} weeks')
    GROUP BY week
    ORDER BY week;
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
  sql_json "
    SELECT type, deep_cause, COUNT(*) AS occurrences,
           GROUP_CONCAT(id, ', ') AS friction_ids
    FROM friction
    WHERE constraint_existed IS NULL
    GROUP BY type, deep_cause
    HAVING COUNT(*) >= ${min}
    ORDER BY occurrences DESC;
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
  sql_json "
    SELECT constraint_existed AS constraint_name,
           MAX(date) AS last_seen,
           COUNT(*) AS total_references
    FROM friction
    WHERE constraint_existed IS NOT NULL
    GROUP BY constraint_existed
    HAVING MAX(date) < date('now', '-${days} days')
    ORDER BY last_seen;
  "
}

cmd_lifecycle() {
  sql_json "
    SELECT status, COUNT(*) AS count,
           GROUP_CONCAT(id, ', ') AS ids
    FROM friction
    GROUP BY status
    ORDER BY CASE status
      WHEN 'captured' THEN 1
      WHEN 'analyzed' THEN 2
      WHEN 'prescribed' THEN 3
      WHEN 'implemented' THEN 4
      WHEN 'verified' THEN 5
    END;
  "
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
