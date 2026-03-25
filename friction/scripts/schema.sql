-- Friction ledger SQLite schema
-- Usage: sqlite3 friction.db < schema.sql

PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;

CREATE TABLE friction (
    id          TEXT PRIMARY KEY,          -- f-YYYYMMDD-NNN
    date        TEXT NOT NULL,             -- YYYY-MM-DD
    project     TEXT NOT NULL,
    type        TEXT NOT NULL,
    description TEXT NOT NULL,
    root_cause  TEXT,
    deep_cause  TEXT,
    resolution  TEXT,
    effort      TEXT CHECK (effort IN ('high','medium','low')),
    constraint_existed TEXT,
    constraint_failed  INTEGER NOT NULL DEFAULT 0,
    recurrence_of      TEXT REFERENCES friction(id),
    prescribed_advisory    TEXT,
    prescribed_structural  TEXT,
    prescribed_mechanical  TEXT,
    implemented_advisory   TEXT,
    implemented_structural TEXT,
    implemented_mechanical TEXT,
    status      TEXT NOT NULL DEFAULT 'captured'
                CHECK (status IN ('captured','analyzed','prescribed','implemented','verified')),
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE friction_domain (
    friction_id TEXT NOT NULL REFERENCES friction(id) ON DELETE CASCADE,
    domain      TEXT NOT NULL,
    PRIMARY KEY (friction_id, domain)
);

-- Indexes for core query patterns
CREATE INDEX idx_friction_date ON friction(date);
CREATE INDEX idx_friction_status ON friction(status);
CREATE INDEX idx_friction_type ON friction(type);
CREATE INDEX idx_friction_constraint ON friction(constraint_existed)
    WHERE constraint_existed IS NOT NULL;
CREATE INDEX idx_domain_tag ON friction_domain(domain);

-- Full-text search on description, root_cause, deep_cause
CREATE VIRTUAL TABLE friction_fts USING fts5(
    id UNINDEXED, description, root_cause, deep_cause,
    content=friction, content_rowid=rowid
);

-- Keep FTS index in sync with friction table
CREATE TRIGGER friction_ai AFTER INSERT ON friction BEGIN
    INSERT INTO friction_fts(rowid, id, description, root_cause, deep_cause)
    VALUES (new.rowid, new.id, new.description, new.root_cause, new.deep_cause);
END;

CREATE TRIGGER friction_au AFTER UPDATE ON friction BEGIN
    INSERT INTO friction_fts(friction_fts, rowid, id, description, root_cause, deep_cause)
    VALUES ('delete', old.rowid, old.id, old.description, old.root_cause, old.deep_cause);
    INSERT INTO friction_fts(rowid, id, description, root_cause, deep_cause)
    VALUES (new.rowid, new.id, new.description, new.root_cause, new.deep_cause);
END;

CREATE TRIGGER friction_ad AFTER DELETE ON friction BEGIN
    INSERT INTO friction_fts(friction_fts, rowid, id, description, root_cause, deep_cause)
    VALUES ('delete', old.rowid, old.id, old.description, old.root_cause, old.deep_cause);
END;
