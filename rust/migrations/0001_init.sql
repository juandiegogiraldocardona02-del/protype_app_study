PRAGMA foreign_keys = ON;

CREATE TABLE profiles (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre      TEXT NOT NULL CHECK (length(trim(nombre)) > 0),
    config_json TEXT NOT NULL DEFAULT '{}',
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE TABLE subjects (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id     INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    nombre         TEXT NOT NULL CHECK (length(trim(nombre)) > 0),
    color          TEXT NOT NULL DEFAULT '#4F46E5',
    xp_config_json TEXT NOT NULL DEFAULT '{}',
    created_at     TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX idx_subjects_profile ON subjects(profile_id);

CREATE TABLE topics (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    parent_id  INTEGER REFERENCES topics(id) ON DELETE CASCADE,
    nombre     TEXT NOT NULL CHECK (length(trim(nombre)) > 0),
    dificultad REAL NOT NULL DEFAULT 1.0,
    dominio    REAL NOT NULL DEFAULT 0.0,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX idx_topics_subject ON topics(subject_id);
CREATE INDEX idx_topics_parent ON topics(parent_id);

CREATE TABLE documents (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    ruta_local TEXT NOT NULL,
    tipo       TEXT NOT NULL,
    hash       TEXT NOT NULL,
    version    INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX idx_documents_subject ON documents(subject_id);
CREATE INDEX idx_documents_hash ON documents(subject_id, hash);

CREATE TABLE document_chunks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    document_id INTEGER NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    texto       TEXT NOT NULL,
    seccion     TEXT
);

CREATE INDEX idx_chunks_document ON document_chunks(document_id);

CREATE TABLE sessions (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_id   INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    topic_id     INTEGER REFERENCES topics(id) ON DELETE SET NULL,
    inicio       TEXT NOT NULL,
    duracion_min INTEGER NOT NULL CHECK (duracion_min > 0),
    estado       TEXT NOT NULL DEFAULT 'pendiente'
                 CHECK (estado IN ('pendiente', 'completada', 'replanificada'))
);

CREATE INDEX idx_sessions_subject ON sessions(subject_id);
CREATE INDEX idx_sessions_topic ON sessions(topic_id);

CREATE TABLE flashcards (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    topic_id         INTEGER NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    pregunta         TEXT NOT NULL,
    respuesta        TEXT NOT NULL,
    intervalo_dias   INTEGER NOT NULL DEFAULT 0,
    proxima_revision TEXT,
    created_at       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX idx_flashcards_topic ON flashcards(topic_id);

CREATE TABLE assessments (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    tipo       TEXT NOT NULL,
    puntuacion REAL NOT NULL DEFAULT 0.0,
    fecha      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX idx_assessments_subject ON assessments(subject_id);

CREATE TABLE xp_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    actividad  TEXT NOT NULL,
    xp         INTEGER NOT NULL,
    timestamp  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX idx_xp_log_profile ON xp_log(profile_id);

CREATE TABLE change_history (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    entidad    TEXT NOT NULL,
    entidad_id INTEGER NOT NULL,
    accion     TEXT NOT NULL,
    timestamp  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX idx_change_history_entity ON change_history(entidad, entidad_id);
