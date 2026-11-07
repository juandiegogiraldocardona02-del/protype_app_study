ALTER TABLE flashcards ADD COLUMN repasos INTEGER NOT NULL DEFAULT 0;

ALTER TABLE flashcards ADD COLUMN factor_facilidad REAL NOT NULL DEFAULT 2.5;

ALTER TABLE flashcards ADD COLUMN ultima_revision TEXT;

ALTER TABLE flashcards ADD COLUMN origen TEXT NOT NULL DEFAULT 'manual';

CREATE INDEX idx_flashcards_proxima ON flashcards(proxima_revision);

CREATE TABLE review_log (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    flashcard_id     INTEGER NOT NULL REFERENCES flashcards(id) ON DELETE CASCADE,
    topic_id         INTEGER NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    calidad          INTEGER NOT NULL CHECK (calidad BETWEEN 0 AND 5),
    intervalo_dias   INTEGER NOT NULL,
    factor_facilidad REAL NOT NULL,
    timestamp        TEXT NOT NULL
);

CREATE INDEX idx_review_log_topic ON review_log(topic_id, timestamp);
