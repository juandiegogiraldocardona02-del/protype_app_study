use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

use chrono::{Days, Duration, Local, NaiveDate, NaiveDateTime, SecondsFormat, Utc};
use rusqlite::{params, Connection, OptionalExtension};

use crate::domain::defaults::{PROFILE_CONFIG, SUBJECT_COLOR, SUBJECT_XP_CONFIG};
use crate::domain::{
    Assessment, AvailabilityDay, Document, Flashcard, FlashcardProposal, MasteryOverview,
    PlanSettings, PlannedSession, Profile, ReviewResult, Session, Streak, Subject, Topic, XpConfig,
};
use crate::error::{CoreError, CoreResult};

const MIGRATIONS: &[(i64, &str)] = &[
    (1, include_str!("../../migrations/0001_init.sql")),
    (
        2,
        include_str!("../../migrations/0002_documents_nombre.sql"),
    ),
    (3, include_str!("../../migrations/0003_planning.sql")),
    (4, include_str!("../../migrations/0004_learning.sql")),
    (5, include_str!("../../migrations/0005_gamification.sql")),
    (6, include_str!("../../migrations/0006_assessments.sql")),
];

const MAX_NAME_LEN: usize = 120;

type StreakRow = (i64, i64, Option<String>, i64, Option<String>);

pub struct NewDocument {
    pub subject_id: i64,
    pub name: String,
    pub local_path: String,
    pub kind: String,
    pub hash: String,
    pub version: i64,
    pub extraction_status: String,
    pub extraction_message: Option<String>,
    pub chunks: Vec<String>,
}

pub struct NewAssessment<'a> {
    pub subject_id: i64,
    pub kind: &'a str,
    pub score: f64,
    pub correct: i64,
    pub total: i64,
    pub threshold: f64,
    pub topic_scores: &'a [(i64, i64, i64)],
}

pub struct Database {
    conn: Connection,
}

impl Database {
    pub fn open(path: impl AsRef<Path>) -> CoreResult<Self> {
        let path = path.as_ref();
        if let Some(parent) = path.parent() {
            if !parent.as_os_str().is_empty() {
                std::fs::create_dir_all(parent)?;
            }
        }
        let conn = Connection::open(path)?;
        Self::from_connection(conn)
    }

    pub fn open_in_memory() -> CoreResult<Self> {
        Self::from_connection(Connection::open_in_memory()?)
    }

    pub(crate) fn connection(&self) -> &Connection {
        &self.conn
    }

    pub(crate) fn connection_mut(&mut self) -> &mut Connection {
        &mut self.conn
    }

    fn from_connection(mut conn: Connection) -> CoreResult<Self> {
        conn.execute_batch(
            "PRAGMA foreign_keys = ON;
             PRAGMA journal_mode = WAL;
             PRAGMA synchronous = NORMAL;
             PRAGMA busy_timeout = 5000;",
        )?;
        apply_migrations(&mut conn)?;
        Ok(Self { conn })
    }

    pub fn create_profile(&mut self, name: &str) -> CoreResult<Profile> {
        let name = validate_name(name)?;
        let tx = self.conn.transaction()?;
        tx.execute(
            "INSERT INTO profiles (nombre, config_json) VALUES (?1, ?2)",
            params![name, PROFILE_CONFIG],
        )?;
        let id = tx.last_insert_rowid();
        log_change(&tx, "profile", id, "crear")?;
        tx.commit()?;
        Ok(Profile {
            id,
            name: name.to_string(),
            config_json: PROFILE_CONFIG.to_string(),
        })
    }

    pub fn list_profiles(&self) -> CoreResult<Vec<Profile>> {
        let mut stmt = self
            .conn
            .prepare("SELECT id, nombre, config_json FROM profiles ORDER BY id ASC")?;
        let rows = stmt.query_map([], |row| {
            Ok(Profile {
                id: row.get(0)?,
                name: row.get(1)?,
                config_json: row.get(2)?,
            })
        })?;
        let mut profiles = Vec::new();
        for row in rows {
            profiles.push(row?);
        }
        Ok(profiles)
    }

    pub fn rename_profile(&mut self, id: i64, name: &str) -> CoreResult<Profile> {
        let name = validate_name(name)?;
        let tx = self.conn.transaction()?;
        let updated = tx.execute(
            "UPDATE profiles SET nombre = ?1 WHERE id = ?2",
            params![name, id],
        )?;
        if updated == 0 {
            return Err(CoreError::NotFound(format!("perfil {id}")));
        }
        log_change(&tx, "profile", id, "renombrar")?;
        tx.commit()?;
        self.get_profile(id)
    }

    pub fn get_profile(&self, id: i64) -> CoreResult<Profile> {
        self.conn
            .query_row(
                "SELECT id, nombre, config_json FROM profiles WHERE id = ?1",
                params![id],
                |row| {
                    Ok(Profile {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        config_json: row.get(2)?,
                    })
                },
            )
            .optional()?
            .ok_or_else(|| CoreError::NotFound(format!("perfil {id}")))
    }

    pub fn delete_profile(&mut self, id: i64) -> CoreResult<()> {
        let tx = self.conn.transaction()?;
        let deleted = tx.execute("DELETE FROM profiles WHERE id = ?1", params![id])?;
        if deleted == 0 {
            return Err(CoreError::NotFound(format!("perfil {id}")));
        }
        log_change(&tx, "profile", id, "eliminar")?;
        tx.commit()?;
        Ok(())
    }

    pub fn create_subject(
        &mut self,
        profile_id: i64,
        name: &str,
        color: &str,
    ) -> CoreResult<Subject> {
        let name = validate_name(name)?;
        let color = normalize_color(color);
        let tx = self.conn.transaction()?;
        let profile_exists: bool = tx
            .query_row(
                "SELECT 1 FROM profiles WHERE id = ?1",
                params![profile_id],
                |row| row.get::<_, i64>(0),
            )
            .optional()?
            .is_some();
        if !profile_exists {
            return Err(CoreError::NotFound(format!("perfil {profile_id}")));
        }
        tx.execute(
            "INSERT INTO subjects (profile_id, nombre, color, xp_config_json)
             VALUES (?1, ?2, ?3, ?4)",
            params![profile_id, name, color, SUBJECT_XP_CONFIG],
        )?;
        let id = tx.last_insert_rowid();
        log_change(&tx, "subject", id, "crear")?;
        tx.commit()?;
        Ok(Subject {
            id,
            profile_id,
            name: name.to_string(),
            color: color.to_string(),
            xp_config_json: SUBJECT_XP_CONFIG.to_string(),
        })
    }

    pub fn list_subjects(&self, profile_id: i64) -> CoreResult<Vec<Subject>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, profile_id, nombre, color, xp_config_json
             FROM subjects WHERE profile_id = ?1 ORDER BY id ASC",
        )?;
        let rows = stmt.query_map(params![profile_id], |row| {
            Ok(Subject {
                id: row.get(0)?,
                profile_id: row.get(1)?,
                name: row.get(2)?,
                color: row.get(3)?,
                xp_config_json: row.get(4)?,
            })
        })?;
        let mut subjects = Vec::new();
        for row in rows {
            subjects.push(row?);
        }
        Ok(subjects)
    }

    pub fn get_subject(&self, id: i64) -> CoreResult<Subject> {
        self.conn
            .query_row(
                "SELECT id, profile_id, nombre, color, xp_config_json
                 FROM subjects WHERE id = ?1",
                params![id],
                |row| {
                    Ok(Subject {
                        id: row.get(0)?,
                        profile_id: row.get(1)?,
                        name: row.get(2)?,
                        color: row.get(3)?,
                        xp_config_json: row.get(4)?,
                    })
                },
            )
            .optional()?
            .ok_or_else(|| CoreError::NotFound(format!("asignatura {id}")))
    }

    pub fn update_subject(&mut self, id: i64, name: &str, color: &str) -> CoreResult<Subject> {
        let name = validate_name(name)?;
        let color = normalize_color(color);
        let tx = self.conn.transaction()?;
        let updated = tx.execute(
            "UPDATE subjects SET nombre = ?1, color = ?2 WHERE id = ?3",
            params![name, color, id],
        )?;
        if updated == 0 {
            return Err(CoreError::NotFound(format!("asignatura {id}")));
        }
        log_change(&tx, "subject", id, "actualizar")?;
        tx.commit()?;
        self.get_subject(id)
    }

    pub fn delete_subject(&mut self, id: i64) -> CoreResult<()> {
        let tx = self.conn.transaction()?;
        let deleted = tx.execute("DELETE FROM subjects WHERE id = ?1", params![id])?;
        if deleted == 0 {
            return Err(CoreError::NotFound(format!("asignatura {id}")));
        }
        log_change(&tx, "subject", id, "eliminar")?;
        tx.commit()?;
        Ok(())
    }

    pub fn find_document_by_hash(
        &self,
        subject_id: i64,
        hash: &str,
    ) -> CoreResult<Option<Document>> {
        self.conn
            .query_row(
                &format!("{DOCUMENT_SELECT} WHERE d.subject_id = ?1 AND d.hash = ?2"),
                params![subject_id, hash],
                map_document,
            )
            .optional()
            .map_err(CoreError::from)
    }

    pub fn next_document_version(&self, subject_id: i64, name: &str) -> CoreResult<i64> {
        Ok(self.conn.query_row(
            "SELECT COALESCE(MAX(version), 0) + 1 FROM documents
             WHERE subject_id = ?1 AND nombre = ?2",
            params![subject_id, name],
            |row| row.get(0),
        )?)
    }

    pub fn insert_document(&mut self, new_document: NewDocument) -> CoreResult<Document> {
        let tx = self.conn.transaction()?;
        tx.execute(
            "INSERT INTO documents
                (subject_id, nombre, ruta_local, tipo, hash, version,
                 extraccion_estado, extraccion_mensaje)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
            params![
                new_document.subject_id,
                new_document.name,
                new_document.local_path,
                new_document.kind,
                new_document.hash,
                new_document.version,
                new_document.extraction_status,
                new_document.extraction_message,
            ],
        )?;
        let id = tx.last_insert_rowid();
        for chunk in &new_document.chunks {
            tx.execute(
                "INSERT INTO document_chunks (document_id, texto) VALUES (?1, ?2)",
                params![id, chunk],
            )?;
        }
        log_change(&tx, "document", id, "crear")?;
        tx.commit()?;
        self.get_document(id)
    }

    pub fn get_document(&self, id: i64) -> CoreResult<Document> {
        self.conn
            .query_row(
                &format!("{DOCUMENT_SELECT} WHERE d.id = ?1"),
                params![id],
                map_document,
            )
            .optional()?
            .ok_or_else(|| CoreError::NotFound(format!("documento {id}")))
    }

    pub fn list_documents(&self, subject_id: i64) -> CoreResult<Vec<Document>> {
        let mut stmt = self.conn.prepare(&format!(
            "{DOCUMENT_SELECT} WHERE d.subject_id = ?1
             ORDER BY d.created_at DESC, d.id DESC"
        ))?;
        let rows = stmt.query_map(params![subject_id], map_document)?;
        let mut documents = Vec::new();
        for row in rows {
            documents.push(row?);
        }
        Ok(documents)
    }

    pub fn list_document_chunks(&self, document_id: i64) -> CoreResult<Vec<String>> {
        let mut stmt = self
            .conn
            .prepare("SELECT texto FROM document_chunks WHERE document_id = ?1 ORDER BY id")?;
        let rows = stmt.query_map(params![document_id], |row| row.get(0))?;
        let mut chunks = Vec::new();
        for row in rows {
            chunks.push(row?);
        }
        Ok(chunks)
    }

    pub fn delete_document(&mut self, id: i64) -> CoreResult<()> {
        let tx = self.conn.transaction()?;
        let deleted = tx.execute("DELETE FROM documents WHERE id = ?1", params![id])?;
        if deleted == 0 {
            return Err(CoreError::NotFound(format!("documento {id}")));
        }
        log_change(&tx, "document", id, "eliminar")?;
        tx.commit()?;
        Ok(())
    }

    pub fn create_topic(
        &mut self,
        subject_id: i64,
        name: &str,
        difficulty: f64,
    ) -> CoreResult<Topic> {
        self.get_subject(subject_id)?;
        let name = validate_name(name)?;
        let difficulty = validate_difficulty(difficulty)?;
        let tx = self.conn.transaction()?;
        tx.execute(
            "INSERT INTO topics (subject_id, nombre, dificultad) VALUES (?1, ?2, ?3)",
            params![subject_id, name, difficulty],
        )?;
        let id = tx.last_insert_rowid();
        log_change(&tx, "topic", id, "crear")?;
        tx.commit()?;
        self.get_topic(id)
    }

    pub fn get_topic(&self, id: i64) -> CoreResult<Topic> {
        self.conn
            .query_row(
                "SELECT id, subject_id, parent_id, nombre, dificultad, dominio
                 FROM topics WHERE id = ?1",
                params![id],
                map_topic,
            )
            .optional()?
            .ok_or_else(|| CoreError::NotFound(format!("tema {id}")))
    }

    pub fn list_topics(&self, subject_id: i64) -> CoreResult<Vec<Topic>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, subject_id, parent_id, nombre, dificultad, dominio
             FROM topics WHERE subject_id = ?1 ORDER BY id",
        )?;
        let rows = stmt.query_map(params![subject_id], map_topic)?;
        let mut topics = Vec::new();
        for row in rows {
            topics.push(row?);
        }
        Ok(topics)
    }

    pub fn update_topic(&mut self, id: i64, name: &str, difficulty: f64) -> CoreResult<Topic> {
        let name = validate_name(name)?;
        let difficulty = validate_difficulty(difficulty)?;
        let tx = self.conn.transaction()?;
        let changed = tx.execute(
            "UPDATE topics SET nombre = ?2, dificultad = ?3 WHERE id = ?1",
            params![id, name, difficulty],
        )?;
        if changed == 0 {
            return Err(CoreError::NotFound(format!("tema {id}")));
        }
        log_change(&tx, "topic", id, "editar")?;
        tx.commit()?;
        self.get_topic(id)
    }

    pub fn delete_topic(&mut self, id: i64) -> CoreResult<()> {
        let tx = self.conn.transaction()?;
        let changed = tx.execute("DELETE FROM topics WHERE id = ?1", params![id])?;
        if changed == 0 {
            return Err(CoreError::NotFound(format!("tema {id}")));
        }
        log_change(&tx, "topic", id, "eliminar")?;
        tx.commit()?;
        Ok(())
    }

    pub fn get_plan_settings(&self, subject_id: i64) -> CoreResult<PlanSettings> {
        self.get_subject(subject_id)?;
        let stored = self
            .conn
            .query_row(
                "SELECT duracion_sesion_min, hora_inicio, fecha_limite
                 FROM plan_settings WHERE subject_id = ?1",
                params![subject_id],
                |row| {
                    Ok((
                        row.get::<_, i64>(0)?,
                        row.get::<_, i64>(1)?,
                        row.get::<_, String>(2)?,
                    ))
                },
            )
            .optional()?;
        let mut availability = self.list_availability(subject_id)?;
        match stored {
            Some((session_minutes, start_hour, deadline)) => Ok(PlanSettings {
                subject_id,
                session_minutes,
                start_hour,
                deadline,
                availability,
            }),
            None => {
                if availability.is_empty() {
                    availability = (1..=5)
                        .map(|weekday| AvailabilityDay {
                            weekday,
                            minutes: 120,
                        })
                        .collect();
                }
                Ok(PlanSettings {
                    subject_id,
                    session_minutes: 50,
                    start_hour: 8,
                    deadline: (Local::now().date_naive() + Days::new(30)).to_string(),
                    availability,
                })
            }
        }
    }

    pub fn list_availability(&self, subject_id: i64) -> CoreResult<Vec<AvailabilityDay>> {
        let mut stmt = self.conn.prepare(
            "SELECT dia_semana, minutos FROM availability
             WHERE subject_id = ?1 ORDER BY dia_semana",
        )?;
        let rows = stmt.query_map(params![subject_id], |row| {
            Ok(AvailabilityDay {
                weekday: row.get(0)?,
                minutes: row.get(1)?,
            })
        })?;
        let mut days = Vec::new();
        for row in rows {
            days.push(row?);
        }
        Ok(days)
    }

    pub fn save_plan_settings(&mut self, settings: &PlanSettings) -> CoreResult<PlanSettings> {
        self.get_subject(settings.subject_id)?;
        if !(15..=240).contains(&settings.session_minutes) {
            return Err(CoreError::Validation(
                "la duración de sesión debe estar entre 15 y 240 minutos".into(),
            ));
        }
        if !(0..=23).contains(&settings.start_hour) {
            return Err(CoreError::Validation(
                "la hora de inicio debe estar entre 0 y 23".into(),
            ));
        }
        if NaiveDate::parse_from_str(&settings.deadline, "%Y-%m-%d").is_err() {
            return Err(CoreError::Validation(
                "la fecha límite debe tener el formato AAAA-MM-DD".into(),
            ));
        }
        if settings.availability.is_empty() {
            return Err(CoreError::Validation(
                "selecciona al menos un día de disponibilidad".into(),
            ));
        }
        let mut seen = std::collections::BTreeSet::new();
        for day in &settings.availability {
            if !(1..=7).contains(&day.weekday) {
                return Err(CoreError::Validation(
                    "el día de la semana debe estar entre 1 (lunes) y 7 (domingo)".into(),
                ));
            }
            if !(1..=1440).contains(&day.minutes) {
                return Err(CoreError::Validation(
                    "los minutos por día deben estar entre 1 y 1440".into(),
                ));
            }
            if !seen.insert(day.weekday) {
                return Err(CoreError::Validation(
                    "hay días de disponibilidad duplicados".into(),
                ));
            }
        }

        let timestamp = Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true);
        let tx = self.conn.transaction()?;
        tx.execute(
            "INSERT INTO plan_settings
                (subject_id, duracion_sesion_min, hora_inicio, fecha_limite,
                 actualizado_en)
             VALUES (?1, ?2, ?3, ?4, ?5)
             ON CONFLICT(subject_id) DO UPDATE SET
                duracion_sesion_min = excluded.duracion_sesion_min,
                hora_inicio = excluded.hora_inicio,
                fecha_limite = excluded.fecha_limite,
                actualizado_en = excluded.actualizado_en",
            params![
                settings.subject_id,
                settings.session_minutes,
                settings.start_hour,
                settings.deadline,
                timestamp,
            ],
        )?;
        tx.execute(
            "DELETE FROM availability WHERE subject_id = ?1",
            params![settings.subject_id],
        )?;
        for day in &settings.availability {
            tx.execute(
                "INSERT INTO availability (subject_id, dia_semana, minutos)
                 VALUES (?1, ?2, ?3)",
                params![settings.subject_id, day.weekday, day.minutes],
            )?;
        }
        log_change(&tx, "subject", settings.subject_id, "configurar_plan")?;
        tx.commit()?;
        self.get_plan_settings(settings.subject_id)
    }

    pub fn replace_pending_sessions(
        &mut self,
        subject_id: i64,
        sessions: &[PlannedSession],
    ) -> CoreResult<i64> {
        if sessions.is_empty() {
            return Err(CoreError::Validation(
                "el plan debe contener al menos una sesión".into(),
            ));
        }
        self.get_subject(subject_id)?;
        for session in sessions {
            if NaiveDateTime::parse_from_str(&session.start, "%Y-%m-%dT%H:%M:%S").is_err() {
                return Err(CoreError::Validation(format!(
                    "fecha de sesión inválida: {}",
                    session.start
                )));
            }
            if session.duration_min <= 0 {
                return Err(CoreError::Validation(
                    "la duración de cada sesión debe ser positiva".into(),
                ));
            }
            if let Some(topic_id) = session.topic_id {
                let count: i64 = self.conn.query_row(
                    "SELECT COUNT(*) FROM topics WHERE id = ?1 AND subject_id = ?2",
                    params![topic_id, subject_id],
                    |row| row.get(0),
                )?;
                if count == 0 {
                    return Err(CoreError::Validation(format!(
                        "el tema {topic_id} no pertenece a la asignatura"
                    )));
                }
            }
        }

        let tx = self.conn.transaction()?;
        tx.execute(
            "DELETE FROM sessions WHERE subject_id = ?1 AND estado <> 'completada'",
            params![subject_id],
        )?;
        for session in sessions {
            tx.execute(
                "INSERT INTO sessions
                    (subject_id, topic_id, inicio, duracion_min, estado)
                 VALUES (?1, ?2, ?3, ?4, 'pendiente')",
                params![
                    subject_id,
                    session.topic_id,
                    session.start,
                    session.duration_min
                ],
            )?;
        }
        log_change(&tx, "subject", subject_id, "guardar_plan")?;
        tx.commit()?;
        Ok(sessions.len() as i64)
    }

    pub fn list_sessions(
        &self,
        profile_id: i64,
        subject_id: Option<i64>,
        start: &str,
        end: &str,
    ) -> CoreResult<Vec<Session>> {
        let mut stmt = self.conn.prepare(
            "SELECT s.id, s.subject_id, s.topic_id, t.nombre, sub.nombre,
                    sub.color, s.inicio, s.duracion_min, s.estado,
                    s.inicio_original
             FROM sessions s
             JOIN subjects sub ON sub.id = s.subject_id
             LEFT JOIN topics t ON t.id = s.topic_id
             WHERE sub.profile_id = ?1
               AND s.inicio >= ?2 AND s.inicio < ?3
               AND (?4 IS NULL OR s.subject_id = ?4)
             ORDER BY s.inicio, s.id",
        )?;
        let rows = stmt.query_map(params![profile_id, start, end, subject_id], map_session)?;
        let mut sessions = Vec::new();
        for row in rows {
            sessions.push(row?);
        }
        Ok(sessions)
    }

    pub fn sessions_for_subject(&self, subject_id: i64) -> CoreResult<Vec<Session>> {
        let mut stmt = self.conn.prepare(
            "SELECT s.id, s.subject_id, s.topic_id, t.nombre, sub.nombre,
                    sub.color, s.inicio, s.duracion_min, s.estado,
                    s.inicio_original
             FROM sessions s
             JOIN subjects sub ON sub.id = s.subject_id
             LEFT JOIN topics t ON t.id = s.topic_id
             WHERE s.subject_id = ?1
             ORDER BY s.inicio, s.id",
        )?;
        let rows = stmt.query_map(params![subject_id], map_session)?;
        let mut sessions = Vec::new();
        for row in rows {
            sessions.push(row?);
        }
        Ok(sessions)
    }

    pub fn set_session_state(&mut self, id: i64, state: &str) -> CoreResult<()> {
        if state != "pendiente" && state != "completada" {
            return Err(CoreError::Validation(
                "estado de sesión no válido; usa pendiente o completada".into(),
            ));
        }
        let info: Option<(i64, Option<i64>, String)> = self
            .conn
            .query_row(
                "SELECT subject_id, topic_id, estado FROM sessions WHERE id = ?1",
                params![id],
                |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
            )
            .optional()?;
        let (subject_id, topic_id, previous) =
            info.ok_or_else(|| CoreError::NotFound(format!("sesión {id}")))?;
        let profile_id: i64 = self.conn.query_row(
            "SELECT profile_id FROM subjects WHERE id = ?1",
            params![subject_id],
            |row| row.get(0),
        )?;
        let config = self.get_xp_config(subject_id)?;
        let now = Local::now();
        let timestamp = Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true);

        let tx = self.conn.transaction()?;
        let changed = tx.execute(
            "UPDATE sessions SET estado = ?2 WHERE id = ?1",
            params![id, state],
        )?;
        if changed == 0 {
            return Err(CoreError::NotFound(format!("sesión {id}")));
        }
        if state == "completada" && previous != "completada" {
            insert_xp_once(
                &tx,
                profile_id,
                &format!("sesion:{id}"),
                config.session,
                &timestamp,
            )?;
            record_streak_tx(
                &tx,
                profile_id,
                now.date_naive(),
                config.streak_7d,
                &timestamp,
            )?;
        }
        log_change(&tx, "session", id, state)?;
        tx.commit()?;
        if let Some(topic_id) = topic_id {
            self.refresh_topic_mastery(topic_id)?;
        }
        Ok(())
    }

    pub fn apply_replan(&mut self, moves: &[(i64, String)]) -> CoreResult<i64> {
        let tx = self.conn.transaction()?;
        for (id, start) in moves {
            if NaiveDateTime::parse_from_str(start, "%Y-%m-%dT%H:%M:%S").is_err() {
                return Err(CoreError::Validation(format!(
                    "fecha de replanificación inválida: {start}"
                )));
            }
            let changed = tx.execute(
                "UPDATE sessions
                 SET inicio = ?2,
                     inicio_original = COALESCE(inicio_original, inicio),
                     estado = 'replanificada'
                 WHERE id = ?1",
                params![id, start],
            )?;
            if changed == 0 {
                return Err(CoreError::NotFound(format!("sesión {id}")));
            }
            log_change(&tx, "session", *id, "replanificar")?;
        }
        tx.commit()?;
        Ok(moves.len() as i64)
    }

    pub fn revert_replan(&mut self, subject_id: i64) -> CoreResult<i64> {
        let tx = self.conn.transaction()?;
        let changed = tx.execute(
            "UPDATE sessions
             SET inicio = COALESCE(inicio_original, inicio),
                 estado = 'pendiente',
                 inicio_original = NULL
             WHERE subject_id = ?1 AND inicio_original IS NOT NULL",
            params![subject_id],
        )?;
        log_change(&tx, "subject", subject_id, "revertir_replan")?;
        tx.commit()?;
        Ok(changed as i64)
    }

    pub fn change_count(&self) -> CoreResult<i64> {
        Ok(self
            .conn
            .query_row("SELECT COUNT(*) FROM change_history", [], |row| row.get(0))?)
    }

    pub fn create_flashcard(
        &mut self,
        topic_id: i64,
        question: &str,
        answer: &str,
    ) -> CoreResult<Flashcard> {
        self.get_topic(topic_id)?;
        let question = validate_text("la pregunta", question, 1000)?;
        let answer = validate_text("la respuesta", answer, 4000)?;
        let tx = self.conn.transaction()?;
        tx.execute(
            "INSERT INTO flashcards (topic_id, pregunta, respuesta, origen)
             VALUES (?1, ?2, ?3, 'manual')",
            params![topic_id, question, answer],
        )?;
        let id = tx.last_insert_rowid();
        log_change(&tx, "flashcard", id, "crear")?;
        tx.commit()?;
        self.get_flashcard(id)
    }

    pub fn get_flashcard(&self, id: i64) -> CoreResult<Flashcard> {
        self.conn
            .query_row(
                &format!("{FLASHCARD_SELECT} WHERE f.id = ?1"),
                params![id],
                map_flashcard,
            )
            .optional()?
            .ok_or_else(|| CoreError::NotFound(format!("tarjeta {id}")))
    }

    pub fn list_flashcards(&self, subject_id: i64) -> CoreResult<Vec<Flashcard>> {
        let mut stmt = self.conn.prepare(&format!(
            "{FLASHCARD_SELECT} WHERE t.subject_id = ?1 ORDER BY f.id"
        ))?;
        let rows = stmt.query_map(params![subject_id], map_flashcard)?;
        collect_flashcards(rows)
    }

    pub fn list_due_flashcards(&self, subject_id: i64, now: &str) -> CoreResult<Vec<Flashcard>> {
        let mut stmt = self.conn.prepare(&format!(
            "{FLASHCARD_SELECT}
             WHERE t.subject_id = ?1
               AND (f.proxima_revision IS NULL OR f.proxima_revision <= ?2)
             ORDER BY COALESCE(f.proxima_revision, ''), f.id"
        ))?;
        let rows = stmt.query_map(params![subject_id, now], map_flashcard)?;
        collect_flashcards(rows)
    }

    pub fn update_flashcard(
        &mut self,
        id: i64,
        question: &str,
        answer: &str,
    ) -> CoreResult<Flashcard> {
        self.get_flashcard(id)?;
        let question = validate_text("la pregunta", question, 1000)?;
        let answer = validate_text("la respuesta", answer, 4000)?;
        let tx = self.conn.transaction()?;
        tx.execute(
            "UPDATE flashcards SET pregunta = ?2, respuesta = ?3 WHERE id = ?1",
            params![id, question, answer],
        )?;
        log_change(&tx, "flashcard", id, "editar")?;
        tx.commit()?;
        self.get_flashcard(id)
    }

    pub fn delete_flashcard(&mut self, id: i64) -> CoreResult<()> {
        let tx = self.conn.transaction()?;
        let deleted = tx.execute("DELETE FROM flashcards WHERE id = ?1", params![id])?;
        if deleted == 0 {
            return Err(CoreError::NotFound(format!("tarjeta {id}")));
        }
        log_change(&tx, "flashcard", id, "eliminar")?;
        tx.commit()?;
        Ok(())
    }

    pub fn review_flashcard_at(
        &mut self,
        id: i64,
        quality: i64,
        now: NaiveDateTime,
    ) -> CoreResult<ReviewResult> {
        let card = self.get_flashcard(id)?;
        let schedule = crate::learning::schedule(
            card.repetitions,
            card.interval_days,
            card.ease_factor,
            quality,
        )?;
        let now_text = now.format("%Y-%m-%dT%H:%M:%S").to_string();
        let next_text = (now + Duration::days(schedule.interval_days))
            .format("%Y-%m-%dT%H:%M:%S")
            .to_string();
        let profile_id: i64 = self.conn.query_row(
            "SELECT profile_id FROM subjects WHERE id = ?1",
            params![card.subject_id],
            |row| row.get(0),
        )?;
        let config = self.get_xp_config(card.subject_id)?;
        let timestamp = Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true);

        let tx = self.conn.transaction()?;
        tx.execute(
            "UPDATE flashcards
             SET intervalo_dias = ?2, repasos = ?3, factor_facilidad = ?4,
                 proxima_revision = ?5, ultima_revision = ?6
             WHERE id = ?1",
            params![
                id,
                schedule.interval_days,
                schedule.repetitions,
                schedule.ease_factor,
                next_text,
                now_text
            ],
        )?;
        tx.execute(
            "INSERT INTO review_log
                (flashcard_id, topic_id, calidad, intervalo_dias,
                 factor_facilidad, timestamp)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                id,
                card.topic_id,
                quality,
                schedule.interval_days,
                schedule.ease_factor,
                now_text
            ],
        )?;
        log_change(&tx, "flashcard", id, "repasar")?;
        record_streak_tx(&tx, profile_id, now.date(), config.streak_7d, &timestamp)?;
        tx.commit()?;

        let mastery = self.refresh_topic_mastery(card.topic_id)?;
        let updated = self.get_flashcard(id)?;
        let message = if schedule.interval_days <= 1 {
            "Repaso registrado. La tarjeta volverá mañana.".to_string()
        } else {
            format!(
                "Repaso registrado. Próxima revisión en {} días.",
                schedule.interval_days
            )
        };
        Ok(ReviewResult {
            flashcard: updated,
            quality,
            mastery,
            message,
        })
    }

    pub fn insert_flashcard_proposals(
        &mut self,
        subject_id: i64,
        proposals: &[FlashcardProposal],
    ) -> CoreResult<i64> {
        self.get_subject(subject_id)?;
        if proposals.is_empty() {
            return Err(CoreError::Validation(
                "selecciona al menos una tarjeta para guardar".to_string(),
            ));
        }
        for proposal in proposals {
            let count: i64 = self.conn.query_row(
                "SELECT COUNT(*) FROM topics WHERE id = ?1 AND subject_id = ?2",
                params![proposal.topic_id, subject_id],
                |row| row.get(0),
            )?;
            if count == 0 {
                return Err(CoreError::Validation(format!(
                    "el tema {} no pertenece a la asignatura",
                    proposal.topic_id
                )));
            }
            validate_text("la pregunta", &proposal.question, 1000)?;
            validate_text("la respuesta", &proposal.answer, 4000)?;
        }
        let tx = self.conn.transaction()?;
        for proposal in proposals {
            tx.execute(
                "INSERT INTO flashcards (topic_id, pregunta, respuesta, origen)
                 VALUES (?1, ?2, ?3, 'auto')",
                params![proposal.topic_id, proposal.question, proposal.answer],
            )?;
        }
        log_change(&tx, "subject", subject_id, "generar_flashcards")?;
        tx.commit()?;
        Ok(proposals.len() as i64)
    }

    pub fn list_mastery(&self, subject_id: i64, now: &str) -> CoreResult<Vec<MasteryOverview>> {
        let mut stmt = self.conn.prepare(
            "SELECT t.id, t.nombre, t.dominio,
                    (SELECT COUNT(*) FROM flashcards f
                     WHERE f.topic_id = t.id
                       AND (f.proxima_revision IS NULL
                            OR f.proxima_revision <= ?2)),
                    (SELECT COUNT(*) FROM review_log r WHERE r.topic_id = t.id)
             FROM topics t
             WHERE t.subject_id = ?1
             ORDER BY t.id",
        )?;
        let rows = stmt.query_map(params![subject_id, now], |row| {
            Ok(MasteryOverview {
                topic_id: row.get(0)?,
                topic_name: row.get(1)?,
                mastery: row.get(2)?,
                due_cards: row.get(3)?,
                reviews: row.get(4)?,
            })
        })?;
        let mut result = Vec::new();
        for row in rows {
            result.push(row?);
        }
        Ok(result)
    }

    pub fn document_snippets(&self, subject_id: i64) -> CoreResult<Vec<(String, String)>> {
        let mut stmt = self.conn.prepare(
            "SELECT c.texto, d.nombre, c.seccion
             FROM document_chunks c
             JOIN documents d ON d.id = c.document_id
             WHERE d.subject_id = ?1
             ORDER BY d.id, c.id
             LIMIT 200",
        )?;
        let rows = stmt.query_map(params![subject_id], |row| {
            let text: String = row.get(0)?;
            let name: String = row.get(1)?;
            let section: Option<String> = row.get(2)?;
            let label = match section {
                Some(section) if !section.trim().is_empty() => {
                    format!("{name} · {}", section.trim())
                }
                _ => name,
            };
            Ok((text, label))
        })?;
        let mut snippets = Vec::new();
        for row in rows {
            snippets.push(row?);
        }
        Ok(snippets)
    }

    pub fn record_assessment(&mut self, new: NewAssessment<'_>) -> CoreResult<Assessment> {
        let NewAssessment {
            subject_id,
            kind,
            score,
            correct,
            total,
            threshold,
            topic_scores,
        } = new;
        self.get_subject(subject_id)?;
        let kind = kind.trim();
        if kind.is_empty() {
            return Err(CoreError::Validation(
                "el tipo de evaluación no puede estar vacío".into(),
            ));
        }
        if !score.is_finite() || !(0.0..=1.0).contains(&score) {
            return Err(CoreError::Validation(
                "la puntuación debe estar entre 0 y 1".into(),
            ));
        }
        if !threshold.is_finite() || !(0.0..=1.0).contains(&threshold) {
            return Err(CoreError::Validation(
                "el umbral debe estar entre 0 y 1".into(),
            ));
        }
        if total <= 0 || correct < 0 || correct > total {
            return Err(CoreError::Validation(
                "el número de aciertos no es válido".into(),
            ));
        }
        for (topic_id, topic_correct, topic_total) in topic_scores {
            if *topic_total <= 0 || *topic_correct < 0 || topic_correct > topic_total {
                return Err(CoreError::Validation(
                    "el resultado por tema no es válido".into(),
                ));
            }
            let topic_subject: i64 = self
                .conn
                .query_row(
                    "SELECT subject_id FROM topics WHERE id = ?1",
                    params![topic_id],
                    |row| row.get(0),
                )
                .optional()?
                .ok_or_else(|| CoreError::NotFound(format!("tema {topic_id}")))?;
            if topic_subject != subject_id {
                return Err(CoreError::Validation(
                    "el tema evaluado no pertenece a la asignatura".into(),
                ));
            }
        }

        let config = self.get_xp_config(subject_id)?;
        let profile_id: i64 = self.conn.query_row(
            "SELECT profile_id FROM subjects WHERE id = ?1",
            params![subject_id],
            |row| row.get(0),
        )?;
        let now = Local::now();
        let timestamp = Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true);

        let tx = self.conn.transaction()?;
        tx.execute(
            "INSERT INTO assessments
                (subject_id, tipo, puntuacion, fecha, aciertos, total, umbral)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            params![subject_id, kind, score, timestamp, correct, total, threshold],
        )?;
        let assessment_id = tx.last_insert_rowid();
        for (topic_id, topic_correct, topic_total) in topic_scores {
            let topic_score = *topic_correct as f64 / *topic_total as f64;
            tx.execute(
                "INSERT INTO assessment_topics
                    (assessment_id, topic_id, aciertos, total, puntuacion)
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                params![
                    assessment_id,
                    topic_id,
                    topic_correct,
                    topic_total,
                    topic_score
                ],
            )?;
        }
        if score >= threshold {
            insert_xp_once(
                &tx,
                profile_id,
                &format!("cuestionario:{assessment_id}"),
                config.quiz_passed,
                &timestamp,
            )?;
        }
        record_streak_tx(
            &tx,
            profile_id,
            now.date_naive(),
            config.streak_7d,
            &timestamp,
        )?;
        log_change(&tx, "assessment", assessment_id, "crear")?;
        tx.commit()?;

        for (topic_id, _, _) in topic_scores {
            self.refresh_topic_mastery(*topic_id)?;
        }

        Ok(Assessment {
            id: assessment_id,
            subject_id,
            kind: kind.to_string(),
            score,
            date: timestamp,
            correct,
            total,
            threshold,
        })
    }

    pub fn list_assessments(&self, subject_id: i64) -> CoreResult<Vec<Assessment>> {
        self.get_subject(subject_id)?;
        let mut stmt = self.conn.prepare(
            "SELECT id, subject_id, tipo, puntuacion, fecha, aciertos, total, umbral
             FROM assessments WHERE subject_id = ?1
             ORDER BY fecha DESC, id DESC",
        )?;
        let rows = stmt.query_map(params![subject_id], |row| {
            Ok(Assessment {
                id: row.get(0)?,
                subject_id: row.get(1)?,
                kind: row.get(2)?,
                score: row.get(3)?,
                date: row.get(4)?,
                correct: row.get(5)?,
                total: row.get(6)?,
                threshold: row.get(7)?,
            })
        })?;
        let mut assessments = Vec::new();
        for row in rows {
            assessments.push(row?);
        }
        Ok(assessments)
    }

    pub(crate) fn assessment_topic_average(&self, topic_id: i64) -> CoreResult<Option<f64>> {
        Ok(self.conn.query_row(
            "SELECT AVG(puntuacion) FROM (
                SELECT at.puntuacion
                FROM assessment_topics at
                JOIN assessments a ON a.id = at.assessment_id
                WHERE at.topic_id = ?1
                ORDER BY a.fecha DESC, a.id DESC
                LIMIT 5
             )",
            params![topic_id],
            |row| row.get(0),
        )?)
    }

    pub(crate) fn refresh_topic_mastery(&mut self, topic_id: i64) -> CoreResult<f64> {
        let review_average: Option<f64> = self.conn.query_row(
            "SELECT AVG(calidad) FROM (
                SELECT calidad FROM review_log
                WHERE topic_id = ?1
                ORDER BY timestamp DESC, id DESC
                LIMIT 5
             )",
            params![topic_id],
            |row| row.get(0),
        )?;
        let minutes: i64 = self.conn.query_row(
            "SELECT COALESCE(SUM(duracion_min), 0) FROM sessions
             WHERE topic_id = ?1 AND estado = 'completada'",
            params![topic_id],
            |row| row.get(0),
        )?;
        let assessment_average = self.assessment_topic_average(topic_id)?;
        let review_component = review_average.unwrap_or(0.0) / 5.0;
        let time_component = (minutes as f64 / 120.0).clamp(0.0, 1.0);
        let base = (0.6 * review_component + 0.4 * time_component).clamp(0.0, 1.0);
        let mastery = match assessment_average {
            Some(average) => (0.7 * base + 0.3 * average).clamp(0.0, 1.0),
            None => base,
        };
        let topic = self.get_topic(topic_id)?;
        let config = self.get_xp_config(topic.subject_id)?;
        let profile_id: i64 = self.conn.query_row(
            "SELECT profile_id FROM subjects WHERE id = ?1",
            params![topic.subject_id],
            |row| row.get(0),
        )?;
        let timestamp = Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true);

        let tx = self.conn.transaction()?;
        let changed = tx.execute(
            "UPDATE topics SET dominio = ?2 WHERE id = ?1",
            params![topic_id, mastery],
        )?;
        if changed == 0 {
            return Err(CoreError::NotFound(format!("tema {topic_id}")));
        }
        if mastery >= 0.8 {
            insert_xp_once(
                &tx,
                profile_id,
                &format!("dominar_tema:{topic_id}"),
                config.master_topic,
                &timestamp,
            )?;
        }
        log_change(&tx, "topic", topic_id, "dominio")?;
        tx.commit()?;
        Ok(mastery)
    }

    pub fn get_xp_config(&self, subject_id: i64) -> CoreResult<XpConfig> {
        let raw: String = self
            .conn
            .query_row(
                "SELECT xp_config_json FROM subjects WHERE id = ?1",
                params![subject_id],
                |row| row.get(0),
            )
            .optional()?
            .ok_or_else(|| CoreError::NotFound(format!("asignatura {subject_id}")))?;
        Ok(serde_json::from_str(&raw).unwrap_or_default())
    }

    pub fn save_xp_config(&mut self, subject_id: i64, config: &XpConfig) -> CoreResult<XpConfig> {
        crate::gamification::validate_config(config)?;
        self.get_subject(subject_id)?;
        let json = serde_json::to_string(config).map_err(|error| {
            CoreError::Unexpected(format!(
                "no se pudo serializar la configuración de XP: {error}"
            ))
        })?;
        let tx = self.conn.transaction()?;
        tx.execute(
            "UPDATE subjects SET xp_config_json = ?2 WHERE id = ?1",
            params![subject_id, json],
        )?;
        log_change(&tx, "subject", subject_id, "configurar_xp")?;
        tx.commit()?;
        self.get_xp_config(subject_id)
    }

    pub fn xp_total(&self, profile_id: i64) -> CoreResult<i64> {
        self.get_profile(profile_id)?;
        Ok(self.conn.query_row(
            "SELECT COALESCE(SUM(xp), 0) FROM xp_log WHERE profile_id = ?1",
            params![profile_id],
            |row| row.get(0),
        )?)
    }

    pub fn streak(&self, profile_id: i64) -> CoreResult<Streak> {
        self.get_profile(profile_id)?;
        let stored: Option<StreakRow> = self
            .conn
            .query_row(
                "SELECT current_days, best_days, last_activity_date,
                        freeze_enabled, freeze_used_on
                 FROM streaks WHERE profile_id = ?1",
                params![profile_id],
                |row| {
                    Ok((
                        row.get(0)?,
                        row.get(1)?,
                        row.get(2)?,
                        row.get(3)?,
                        row.get(4)?,
                    ))
                },
            )
            .optional()?;
        let (current_days, best_days, last, freeze, freeze_used_on) =
            stored.unwrap_or((0, 0, None, 1, None));
        Ok(Streak {
            profile_id,
            current_days,
            best_days,
            last_activity_date: last,
            freeze_enabled: freeze != 0,
            freeze_used_on,
        })
    }

    pub fn review_count(&self, profile_id: i64) -> CoreResult<i64> {
        self.get_profile(profile_id)?;
        Ok(self.conn.query_row(
            "SELECT COUNT(*)
             FROM review_log r
             JOIN flashcards f ON f.id = r.flashcard_id
             JOIN topics t ON t.id = f.topic_id
             JOIN subjects s ON s.id = t.subject_id
             WHERE s.profile_id = ?1",
            params![profile_id],
            |row| row.get(0),
        )?)
    }

    pub fn completed_session_count(&self, profile_id: i64) -> CoreResult<i64> {
        self.get_profile(profile_id)?;
        Ok(self.conn.query_row(
            "SELECT COUNT(*)
             FROM sessions se
             JOIN subjects s ON s.id = se.subject_id
             WHERE s.profile_id = ?1 AND se.estado = 'completada'",
            params![profile_id],
            |row| row.get(0),
        )?)
    }

    pub fn mastered_topic_count(&self, profile_id: i64) -> CoreResult<i64> {
        self.get_profile(profile_id)?;
        Ok(self.conn.query_row(
            "SELECT COUNT(*)
             FROM topics t
             JOIN subjects s ON s.id = t.subject_id
             WHERE s.profile_id = ?1 AND t.dominio >= 0.8",
            params![profile_id],
            |row| row.get(0),
        )?)
    }

    pub fn record_activity_at(
        &mut self,
        profile_id: i64,
        today: NaiveDate,
        streak_xp: i64,
    ) -> CoreResult<Streak> {
        self.get_profile(profile_id)?;
        let timestamp = Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true);
        let tx = self.conn.transaction()?;
        record_streak_tx(&tx, profile_id, today, streak_xp, &timestamp)?;
        tx.commit()?;
        self.streak(profile_id)
    }
}

const DOCUMENT_SELECT: &str = "SELECT d.id, d.subject_id, d.nombre, d.ruta_local, d.tipo,
       d.hash, d.version, d.extraccion_estado, d.extraccion_mensaje,
       COALESCE(
           (SELECT SUM(length(c.texto)) FROM document_chunks c
            WHERE c.document_id = d.id), 0)
FROM documents d";

const FLASHCARD_SELECT: &str = "SELECT f.id, f.topic_id, t.nombre, t.subject_id,
       f.pregunta, f.respuesta, f.intervalo_dias, f.repasos, f.factor_facilidad,
       f.proxima_revision, f.ultima_revision, f.origen
FROM flashcards f
JOIN topics t ON t.id = f.topic_id";

fn map_document(row: &rusqlite::Row<'_>) -> rusqlite::Result<Document> {
    Ok(Document {
        id: row.get(0)?,
        subject_id: row.get(1)?,
        name: row.get(2)?,
        local_path: row.get(3)?,
        kind: row.get(4)?,
        hash: row.get(5)?,
        version: row.get(6)?,
        extraction_status: row.get(7)?,
        extraction_message: row.get(8)?,
        text_chars: row.get(9)?,
    })
}

fn map_flashcard(row: &rusqlite::Row<'_>) -> rusqlite::Result<Flashcard> {
    Ok(Flashcard {
        id: row.get(0)?,
        topic_id: row.get(1)?,
        topic_name: row.get(2)?,
        subject_id: row.get(3)?,
        question: row.get(4)?,
        answer: row.get(5)?,
        interval_days: row.get(6)?,
        repetitions: row.get(7)?,
        ease_factor: row.get(8)?,
        next_review: row.get(9)?,
        last_review: row.get(10)?,
        origin: row.get(11)?,
    })
}

fn collect_flashcards(
    rows: rusqlite::MappedRows<'_, impl FnMut(&rusqlite::Row<'_>) -> rusqlite::Result<Flashcard>>,
) -> CoreResult<Vec<Flashcard>> {
    let mut flashcards = Vec::new();
    for row in rows {
        flashcards.push(row?);
    }
    Ok(flashcards)
}

fn map_topic(row: &rusqlite::Row<'_>) -> rusqlite::Result<Topic> {
    Ok(Topic {
        id: row.get(0)?,
        subject_id: row.get(1)?,
        parent_id: row.get(2)?,
        name: row.get(3)?,
        difficulty: row.get(4)?,
        mastery: row.get(5)?,
    })
}

fn map_session(row: &rusqlite::Row<'_>) -> rusqlite::Result<Session> {
    Ok(Session {
        id: row.get(0)?,
        subject_id: row.get(1)?,
        topic_id: row.get(2)?,
        topic_name: row.get(3)?,
        subject_name: row.get(4)?,
        subject_color: row.get(5)?,
        start: row.get(6)?,
        duration_min: row.get(7)?,
        state: row.get(8)?,
        original_start: row.get(9)?,
    })
}

fn validate_difficulty(value: f64) -> CoreResult<f64> {
    if !value.is_finite() || !(1.0..=5.0).contains(&value) {
        return Err(CoreError::Validation(
            "la dificultad debe estar entre 1 y 5".to_string(),
        ));
    }
    Ok(value)
}

fn validate_name(name: &str) -> CoreResult<&str> {
    let trimmed = name.trim();
    if trimmed.is_empty() {
        return Err(CoreError::Validation(
            "el nombre no puede estar vacío".to_string(),
        ));
    }
    if trimmed.chars().count() > MAX_NAME_LEN {
        return Err(CoreError::Validation(format!(
            "el nombre no puede superar {MAX_NAME_LEN} caracteres"
        )));
    }
    Ok(trimmed)
}

fn validate_text<'a>(label: &str, value: &'a str, max_len: usize) -> CoreResult<&'a str> {
    let trimmed = value.trim();
    if trimmed.is_empty() {
        return Err(CoreError::Validation(format!(
            "{label} no puede estar vacía"
        )));
    }
    if trimmed.chars().count() > max_len {
        return Err(CoreError::Validation(format!(
            "{label} no puede superar {max_len} caracteres"
        )));
    }
    Ok(trimmed)
}

fn normalize_color(color: &str) -> &str {
    let trimmed = color.trim();
    if trimmed.is_empty() {
        SUBJECT_COLOR
    } else {
        trimmed
    }
}

fn log_change(
    tx: &rusqlite::Transaction<'_>,
    entity: &str,
    entity_id: i64,
    action: &str,
) -> CoreResult<()> {
    let timestamp = Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true);
    tx.execute(
        "INSERT INTO change_history (entidad, entidad_id, accion, timestamp)
         VALUES (?1, ?2, ?3, ?4)",
        params![entity, entity_id, action, timestamp],
    )?;
    Ok(())
}

fn parse_activity_date(value: &str) -> Option<NaiveDate> {
    NaiveDate::parse_from_str(value, "%Y-%m-%d").ok()
}

fn insert_xp_log(
    tx: &rusqlite::Transaction<'_>,
    profile_id: i64,
    activity: &str,
    xp: i64,
    timestamp: &str,
) -> CoreResult<()> {
    if xp <= 0 {
        return Ok(());
    }
    tx.execute(
        "INSERT INTO xp_log (profile_id, actividad, xp, timestamp)
         VALUES (?1, ?2, ?3, ?4)",
        params![profile_id, activity, xp, timestamp],
    )?;
    log_change(tx, "profile", profile_id, "xp")?;
    Ok(())
}

fn insert_xp_once(
    tx: &rusqlite::Transaction<'_>,
    profile_id: i64,
    activity: &str,
    xp: i64,
    timestamp: &str,
) -> CoreResult<()> {
    if xp <= 0 {
        return Ok(());
    }
    let count: i64 = tx.query_row(
        "SELECT COUNT(*) FROM xp_log WHERE profile_id = ?1 AND actividad = ?2",
        params![profile_id, activity],
        |row| row.get(0),
    )?;
    if count == 0 {
        insert_xp_log(tx, profile_id, activity, xp, timestamp)?;
    }
    Ok(())
}

fn record_streak_tx(
    tx: &rusqlite::Transaction<'_>,
    profile_id: i64,
    today: NaiveDate,
    streak_xp: i64,
    timestamp: &str,
) -> CoreResult<()> {
    let stored: Option<StreakRow> = tx
        .query_row(
            "SELECT current_days, best_days, last_activity_date,
                    freeze_enabled, freeze_used_on
             FROM streaks WHERE profile_id = ?1",
            params![profile_id],
            |row| {
                Ok((
                    row.get(0)?,
                    row.get(1)?,
                    row.get(2)?,
                    row.get(3)?,
                    row.get(4)?,
                ))
            },
        )
        .optional()?;
    let (current_days, best_days, last, freeze, freeze_used_on) =
        stored.unwrap_or((0, 0, None, 1, None));
    let last_date = last.as_deref().and_then(parse_activity_date);
    let freeze_date = freeze_used_on.as_deref().and_then(parse_activity_date);
    let advance = crate::gamification::advance_streak(
        current_days,
        best_days,
        last_date,
        freeze != 0,
        freeze_date,
        today,
    );
    tx.execute(
        "INSERT INTO streaks
            (profile_id, current_days, best_days, last_activity_date,
             freeze_enabled, freeze_used_on)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6)
         ON CONFLICT(profile_id) DO UPDATE SET
            current_days = excluded.current_days,
            best_days = excluded.best_days,
            last_activity_date = excluded.last_activity_date,
            freeze_used_on = excluded.freeze_used_on",
        params![
            profile_id,
            advance.current_days,
            advance.best_days,
            advance.last_activity_date.to_string(),
            freeze,
            advance.freeze_used_on.map(|date| date.to_string()),
        ],
    )?;
    if let Some(milestone) = advance.milestone {
        insert_xp_log(
            tx,
            profile_id,
            &format!("racha_7d:{milestone}"),
            streak_xp,
            timestamp,
        )?;
    }
    log_change(tx, "profile", profile_id, "racha")?;
    Ok(())
}

fn apply_migrations(conn: &mut Connection) -> CoreResult<()> {
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS schema_migrations (
             version    INTEGER PRIMARY KEY,
             applied_at TEXT NOT NULL
         );",
    )?;
    for (version, sql) in MIGRATIONS {
        let applied: bool = conn
            .query_row(
                "SELECT 1 FROM schema_migrations WHERE version = ?1",
                params![version],
                |row| row.get::<_, i64>(0),
            )
            .optional()?
            .is_some();
        if applied {
            continue;
        }
        let tx = conn.transaction()?;
        tx.execute_batch(sql)?;
        tx.execute(
            "INSERT INTO schema_migrations (version, applied_at) VALUES (?1, ?2)",
            params![
                version,
                Utc::now().to_rfc3339_opts(SecondsFormat::Millis, true)
            ],
        )?;
        tx.commit()?;
    }
    Ok(())
}

static DATABASE: OnceLock<Mutex<Database>> = OnceLock::new();
static MODELS_DIRECTORY: OnceLock<PathBuf> = OnceLock::new();
static DATA_DIRECTORY: OnceLock<PathBuf> = OnceLock::new();

pub fn initialize(path: &str) -> CoreResult<()> {
    if DATABASE.get().is_some() {
        return Ok(());
    }
    let database = Database::open(path)?;
    if let Some(parent) = Path::new(path).parent() {
        let _ = MODELS_DIRECTORY.set(parent.join("models"));
        let _ = DATA_DIRECTORY.set(parent.to_path_buf());
    }
    DATABASE
        .set(Mutex::new(database))
        .map_err(|_| CoreError::InvalidState("la base de datos ya fue inicializada".into()))
}

pub fn models_directory() -> Option<PathBuf> {
    MODELS_DIRECTORY.get().cloned()
}

pub fn data_directory() -> Option<PathBuf> {
    DATA_DIRECTORY.get().cloned()
}

pub fn with_db<T>(f: impl FnOnce(&mut Database) -> CoreResult<T>) -> CoreResult<T> {
    let database = DATABASE.get().ok_or_else(|| {
        CoreError::InvalidState("la base de datos no ha sido inicializada".into())
    })?;
    let mut guard = database.lock().map_err(|_| {
        CoreError::Unexpected("el cerrojo de la base de datos está envenenado".into())
    })?;
    f(&mut guard)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_db_path(tag: &str) -> std::path::PathBuf {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("reloj del sistema")
            .as_nanos();
        std::env::temp_dir().join(format!(
            "study_planner_{tag}_{}_{nanos}.sqlite",
            std::process::id()
        ))
    }

    #[test]
    fn creates_and_lists_profiles() {
        let mut db = Database::open_in_memory().expect("abrir bd");
        let ana = db.create_profile("Ana").expect("crear perfil");
        let luis = db.create_profile("Luis").expect("crear perfil");
        let profiles = db.list_profiles().expect("listar");
        assert_eq!(profiles.len(), 2);
        assert_eq!(profiles[0].id, ana.id);
        assert_eq!(profiles[1].id, luis.id);
    }

    #[test]
    fn trims_profile_name() {
        let mut db = Database::open_in_memory().expect("abrir bd");
        let profile = db.create_profile("  Ana  ").expect("crear perfil");
        assert_eq!(profile.name, "Ana");
    }

    #[test]
    fn rejects_empty_names() {
        let mut db = Database::open_in_memory().expect("abrir bd");
        let error = db.create_profile("   ").expect_err("debe fallar");
        assert!(matches!(error, CoreError::Validation(_)));

        let profile = db.create_profile("Ana").expect("crear perfil");
        let error = db
            .create_subject(profile.id, "", "#000000")
            .expect_err("debe fallar");
        assert!(matches!(error, CoreError::Validation(_)));
    }

    #[test]
    fn isolates_subjects_between_profiles() {
        let mut db = Database::open_in_memory().expect("abrir bd");
        let ana = db.create_profile("Ana").expect("perfil ana");
        let luis = db.create_profile("Luis").expect("perfil luis");

        db.create_subject(ana.id, "Matemáticas", "#111111")
            .expect("materia ana");
        db.create_subject(luis.id, "Historia", "#222222")
            .expect("materia luis");

        let ana_subjects = db.list_subjects(ana.id).expect("materias ana");
        let luis_subjects = db.list_subjects(luis.id).expect("materias luis");

        assert_eq!(ana_subjects.len(), 1);
        assert_eq!(ana_subjects[0].name, "Matemáticas");
        assert_eq!(luis_subjects.len(), 1);
        assert_eq!(luis_subjects[0].name, "Historia");
    }

    #[test]
    fn rejects_subject_for_unknown_profile() {
        let mut db = Database::open_in_memory().expect("abrir bd");
        let error = db
            .create_subject(999, "Física", "#333333")
            .expect_err("debe fallar");
        assert!(matches!(error, CoreError::NotFound(_)));
    }

    #[test]
    fn updates_and_deletes_subject() {
        let mut db = Database::open_in_memory().expect("abrir bd");
        let profile = db.create_profile("Ana").expect("perfil");
        let subject = db
            .create_subject(profile.id, "Química", "")
            .expect("materia");
        assert_eq!(subject.color, SUBJECT_COLOR);

        let updated = db
            .update_subject(subject.id, "Química orgánica", "#ABCDEF")
            .expect("actualizar");
        assert_eq!(updated.name, "Química orgánica");
        assert_eq!(updated.color, "#ABCDEF");

        db.delete_subject(subject.id).expect("eliminar");
        assert!(db.list_subjects(profile.id).expect("listar").is_empty());
    }

    #[test]
    fn deleting_profile_cascades_subjects() {
        let mut db = Database::open_in_memory().expect("abrir bd");
        let profile = db.create_profile("Ana").expect("perfil");
        db.create_subject(profile.id, "Matemáticas", "#111111")
            .expect("materia");

        db.delete_profile(profile.id).expect("eliminar perfil");
        assert!(db.list_profiles().expect("perfiles").is_empty());
        assert!(db.list_subjects(profile.id).expect("materias").is_empty());
    }

    #[test]
    fn persists_data_across_reopen() {
        let path = temp_db_path("persist");
        {
            let mut db = Database::open(&path).expect("abrir bd");
            let profile = db.create_profile("Ana").expect("perfil");
            db.create_subject(profile.id, "Matemáticas", "#111111")
                .expect("materia");
        }
        {
            let db = Database::open(&path).expect("reabrir bd");
            let profiles = db.list_profiles().expect("perfiles");
            assert_eq!(profiles.len(), 1);
            let subjects = db.list_subjects(profiles[0].id).expect("materias");
            assert_eq!(subjects.len(), 1);
            assert_eq!(subjects[0].name, "Matemáticas");
        }
        let _ = std::fs::remove_file(&path);
    }

    #[test]
    fn records_change_history() {
        let mut db = Database::open_in_memory().expect("abrir bd");
        let profile = db.create_profile("Ana").expect("perfil");
        db.create_subject(profile.id, "Matemáticas", "#111111")
            .expect("materia");
        assert_eq!(db.change_count().expect("historial"), 2);
    }
}
