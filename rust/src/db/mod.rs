use std::path::Path;
use std::sync::{Mutex, OnceLock};

use chrono::{SecondsFormat, Utc};
use rusqlite::{params, Connection, OptionalExtension};

use crate::domain::defaults::{PROFILE_CONFIG, SUBJECT_COLOR, SUBJECT_XP_CONFIG};
use crate::domain::{Profile, Subject};
use crate::error::{CoreError, CoreResult};

const MIGRATIONS: &[(i64, &str)] = &[(1, include_str!("../../migrations/0001_init.sql"))];

const MAX_NAME_LEN: usize = 120;

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

    pub fn change_count(&self) -> CoreResult<i64> {
        Ok(self
            .conn
            .query_row("SELECT COUNT(*) FROM change_history", [], |row| row.get(0))?)
    }
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

pub fn initialize(path: &str) -> CoreResult<()> {
    if DATABASE.get().is_some() {
        return Ok(());
    }
    let database = Database::open(path)?;
    DATABASE
        .set(Mutex::new(database))
        .map_err(|_| CoreError::InvalidState("la base de datos ya fue inicializada".into()))
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
