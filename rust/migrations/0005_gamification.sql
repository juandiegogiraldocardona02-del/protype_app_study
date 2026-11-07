CREATE TABLE streaks (
    profile_id          INTEGER PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
    current_days        INTEGER NOT NULL DEFAULT 0,
    best_days           INTEGER NOT NULL DEFAULT 0,
    last_activity_date  TEXT,
    freeze_enabled      INTEGER NOT NULL DEFAULT 1,
    freeze_used_on      TEXT
);
