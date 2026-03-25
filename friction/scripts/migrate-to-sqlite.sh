#!/usr/bin/env bash
# One-time migration: ledger.jsonl → friction.db
# Uses Python with parameterized queries for safe insertion.
set -euo pipefail

FRICTION_DIR="${HOME}/.claude/friction"
LEDGER="${FRICTION_DIR}/ledger.jsonl"
DB="${FRICTION_DIR}/friction.db"
SCHEMA="${FRICTION_DIR}/scripts/schema.sql"

[ -f "$LEDGER" ] || { echo "No ledger.jsonl found at $LEDGER" >&2; exit 1; }
[ -f "$SCHEMA" ] || { echo "No schema.sql found at $SCHEMA" >&2; exit 1; }

# Backup existing DB if present
[ -f "$DB" ] && mv "$DB" "${DB}.bak.$(date +%s)"

# Create schema
sqlite3 "$DB" < "$SCHEMA"

# Migrate using Python for safe parameterized queries
python3 - "$DB" "$LEDGER" <<'PYEOF'
import json, sys, sqlite3

db_path, ledger_path = sys.argv[1], sys.argv[2]
conn = sqlite3.connect(db_path)
conn.execute("PRAGMA foreign_keys=ON")

with open(ledger_path) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        e = json.loads(line)
        prescribed = e.get("prescribed") or {}
        implemented = e.get("implemented") or {}

        conn.execute("""
            INSERT INTO friction (
                id, date, project, type, description,
                root_cause, deep_cause, resolution, effort,
                constraint_existed, constraint_failed, recurrence_of,
                prescribed_advisory, prescribed_structural, prescribed_mechanical,
                implemented_advisory, implemented_structural, implemented_mechanical,
                status
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            e["id"], e["date"], e["project"], e["type"], e["description"],
            e.get("root_cause"), e.get("deep_cause"), e.get("resolution"), e.get("effort"),
            e.get("constraint_existed"), 1 if e.get("constraint_failed") else 0,
            e.get("recurrence_of"),
            prescribed.get("advisory"), prescribed.get("structural"), prescribed.get("mechanical"),
            implemented.get("advisory"), implemented.get("structural"), implemented.get("mechanical"),
            e.get("status", "captured"),
        ))

        for tag in (e.get("domain") or []):
            conn.execute(
                "INSERT INTO friction_domain (friction_id, domain) VALUES (?, ?)",
                (e["id"], tag),
            )

conn.commit()

# Report
count = conn.execute("SELECT COUNT(*) FROM friction").fetchone()[0]
domains = conn.execute("SELECT COUNT(*) FROM friction_domain").fetchone()[0]
print(f"Migrated {count} friction entries, {domains} domain tags")
conn.close()
PYEOF

# Archive the JSONL
ARCHIVE="${LEDGER}.archived.$(date +%Y%m%d)"
mv "$LEDGER" "$ARCHIVE"
echo "Archived ledger.jsonl → $(basename "$ARCHIVE")"
