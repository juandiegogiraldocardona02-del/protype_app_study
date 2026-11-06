ALTER TABLE sessions ADD COLUMN inicio_original TEXT;

CREATE INDEX idx_sessions_subject_inicio ON sessions(subject_id, inicio);

CREATE TABLE plan_settings (
    subject_id          INTEGER PRIMARY KEY REFERENCES subjects(id) ON DELETE CASCADE,
    duracion_sesion_min INTEGER NOT NULL DEFAULT 50
                        CHECK (duracion_sesion_min BETWEEN 15 AND 240),
    hora_inicio         INTEGER NOT NULL DEFAULT 8
                        CHECK (hora_inicio BETWEEN 0 AND 23),
    fecha_limite        TEXT NOT NULL DEFAULT '',
    actualizado_en      TEXT NOT NULL DEFAULT ''
);

CREATE TABLE availability (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    dia_semana INTEGER NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    minutos    INTEGER NOT NULL CHECK (minutos BETWEEN 1 AND 1440),
    UNIQUE (subject_id, dia_semana)
);

CREATE INDEX idx_availability_subject ON availability(subject_id);
