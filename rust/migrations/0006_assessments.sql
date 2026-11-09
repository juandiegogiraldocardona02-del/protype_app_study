ALTER TABLE assessments ADD COLUMN aciertos INTEGER NOT NULL DEFAULT 0;

ALTER TABLE assessments ADD COLUMN total INTEGER NOT NULL DEFAULT 0;

ALTER TABLE assessments ADD COLUMN umbral REAL NOT NULL DEFAULT 0.6;

CREATE TABLE assessment_topics (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    assessment_id INTEGER NOT NULL REFERENCES assessments(id) ON DELETE CASCADE,
    topic_id      INTEGER NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    aciertos      INTEGER NOT NULL DEFAULT 0,
    total         INTEGER NOT NULL DEFAULT 0,
    puntuacion    REAL NOT NULL DEFAULT 0.0
);

CREATE INDEX idx_assessment_topics_assessment
    ON assessment_topics(assessment_id);

CREATE INDEX idx_assessment_topics_topic
    ON assessment_topics(topic_id);
