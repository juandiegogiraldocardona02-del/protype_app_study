//! Exportación/importación `.studyplan` y copias globales (Etapa E7).
//!
//! El formato es un ZIP con `manifest.json`, `integrity.json` y los archivos
//! originales de los documentos. El manifiesto es JSON versionado y la
//! integridad se verifica con SHA-256 tanto del manifiesto como de cada
//! documento empaquetado.

use std::collections::{BTreeMap, HashMap, HashSet};
use std::fs::{self, File};
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

use chrono::Utc;
use rusqlite::{params, Connection, OptionalExtension, Transaction};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use zip::write::SimpleFileOptions;
use zip::{CompressionMethod, ZipArchive, ZipWriter};

use crate::db::{self, Database};
use crate::error::{CoreError, CoreResult};

const FORMAT_STUDY_PLAN: &str = "studyplan";
const FORMAT_BACKUP: &str = "studyplanner-backup";
const FORMAT_VERSION: i64 = 1;
const MANIFEST_ENTRY: &str = "manifest.json";
const INTEGRITY_ENTRY: &str = "integrity.json";
const COPY_BUFFER: usize = 64 * 1024;

#[derive(Debug, Clone, Default)]
pub struct BackupCounts {
    pub profiles: i64,
    pub subjects: i64,
    pub topics: i64,
    pub documents: i64,
    pub chunks: i64,
    pub sessions: i64,
    pub flashcards: i64,
    pub reviews: i64,
    pub assessments: i64,
    pub xp_entries: i64,
    pub changes: i64,
}

#[derive(Debug, Clone)]
pub struct ExportResult {
    pub path: String,
    pub bytes: i64,
    pub checksum: String,
    pub counts: BackupCounts,
    pub message: String,
}

#[derive(Debug, Clone)]
pub struct StudyPlanPreview {
    pub subject_name: String,
    pub profile_name: String,
    pub counts: BackupCounts,
    pub conflict: bool,
    pub message: String,
}

#[derive(Debug, Clone)]
pub struct StudyPlanImport {
    pub subject_id: i64,
    pub subject_name: String,
    pub profile_id: i64,
    pub counts: BackupCounts,
    pub requires_confirmation: bool,
    pub message: String,
}

#[derive(Debug, Clone)]
pub struct BackupPreview {
    pub profile_names: Vec<String>,
    pub counts: BackupCounts,
    pub conflict: bool,
    pub message: String,
}

#[derive(Debug, Clone)]
pub struct BackupRestore {
    pub counts: BackupCounts,
    pub requires_confirmation: bool,
    pub message: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Manifest {
    format: String,
    format_version: i64,
    exported_at: String,
    profiles: Vec<ProfileRecord>,
    subjects: Vec<SubjectRecord>,
    changes: Vec<ChangeRecord>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Integrity {
    manifest_sha256: String,
    files: BTreeMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ProfileRecord {
    old_id: i64,
    name: String,
    config_json: String,
    created_at: String,
    xp_log: Vec<XpLogRecord>,
    streak: Option<StreakRecord>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct SubjectRecord {
    old_id: i64,
    profile_old_id: i64,
    name: String,
    color: String,
    xp_config_json: String,
    created_at: String,
    plan_settings: Option<PlanSettingsRecord>,
    availability: Vec<AvailabilityRecord>,
    topics: Vec<TopicRecord>,
    documents: Vec<DocumentRecord>,
    sessions: Vec<SessionRecord>,
    flashcards: Vec<FlashcardRecord>,
    reviews: Vec<ReviewRecord>,
    assessments: Vec<AssessmentRecord>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct PlanSettingsRecord {
    session_minutes: i64,
    start_hour: i64,
    deadline: String,
    updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AvailabilityRecord {
    weekday: i64,
    minutes: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct TopicRecord {
    old_id: i64,
    parent_old_id: Option<i64>,
    name: String,
    difficulty: f64,
    mastery: f64,
    created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct DocumentRecord {
    old_id: i64,
    name: String,
    #[serde(default, skip_serializing)]
    local_path: String,
    kind: String,
    hash: String,
    version: i64,
    created_at: String,
    extraction_status: String,
    extraction_message: Option<String>,
    chunks: Vec<ChunkRecord>,
    archive_path: Option<String>,
    file_sha256: Option<String>,
    #[serde(skip, default)]
    source_path: Option<PathBuf>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ChunkRecord {
    text: String,
    section: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct SessionRecord {
    old_id: i64,
    topic_old_id: Option<i64>,
    start: String,
    duration_min: i64,
    state: String,
    original_start: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct FlashcardRecord {
    old_id: i64,
    topic_old_id: i64,
    question: String,
    answer: String,
    interval_days: i64,
    next_review: Option<String>,
    created_at: String,
    repetitions: i64,
    ease_factor: f64,
    last_review: Option<String>,
    origin: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ReviewRecord {
    old_id: i64,
    flashcard_old_id: i64,
    topic_old_id: i64,
    quality: i64,
    interval_days: i64,
    ease_factor: f64,
    timestamp: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct AssessmentRecord {
    old_id: i64,
    kind: String,
    score: f64,
    date: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ChangeRecord {
    old_id: i64,
    entity: String,
    entity_old_id: i64,
    action: String,
    timestamp: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct XpLogRecord {
    old_id: i64,
    activity: String,
    xp: i64,
    timestamp: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct StreakRecord {
    current_days: i64,
    best_days: i64,
    last_activity_date: Option<String>,
    freeze_enabled: i64,
    freeze_used_on: Option<String>,
}

#[derive(Debug, Default)]
struct SubjectIdMaps {
    old_subject_id: i64,
    subject_id: i64,
    topics: HashMap<i64, i64>,
    documents: HashMap<i64, i64>,
    sessions: HashMap<i64, i64>,
    flashcards: HashMap<i64, i64>,
    assessments: HashMap<i64, i64>,
}

impl BackupCounts {
    fn add_subject(&mut self, subject: &SubjectRecord) {
        self.subjects += 1;
        self.topics += subject.topics.len() as i64;
        self.documents += subject.documents.len() as i64;
        self.chunks += subject
            .documents
            .iter()
            .map(|document| document.chunks.len() as i64)
            .sum::<i64>();
        self.sessions += subject.sessions.len() as i64;
        self.flashcards += subject.flashcards.len() as i64;
        self.reviews += subject.reviews.len() as i64;
        self.assessments += subject.assessments.len() as i64;
    }
}

fn counts_for(manifest: &Manifest) -> BackupCounts {
    let mut counts = BackupCounts {
        profiles: manifest.profiles.len() as i64,
        changes: manifest.changes.len() as i64,
        xp_entries: manifest
            .profiles
            .iter()
            .map(|profile| profile.xp_log.len() as i64)
            .sum(),
        ..BackupCounts::default()
    };
    for subject in &manifest.subjects {
        counts.add_subject(subject);
    }
    counts
}

fn json_error(error: serde_json::Error) -> CoreError {
    CoreError::Unexpected(format!("JSON inválido en la copia: {error}"))
}

fn zip_error(error: zip::result::ZipError) -> CoreError {
    CoreError::Unexpected(format!("archivo comprimido inválido: {error}"))
}

fn hash_bytes(bytes: &[u8]) -> String {
    hex::encode(Sha256::digest(bytes))
}

fn hash_file(path: &Path) -> CoreResult<String> {
    let mut file = File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0_u8; COPY_BUFFER];
    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }
    Ok(hex::encode(hasher.finalize()))
}

fn sanitize_name(name: &str) -> String {
    let mut result = String::with_capacity(name.len());
    for character in name.chars() {
        if character.is_alphanumeric() || matches!(character, '-' | '_' | '.') {
            result.push(character);
        } else if character.is_whitespace() {
            result.push('_');
        }
    }
    let trimmed = result.trim_matches('_').trim_matches('.');
    if trimmed.is_empty() {
        "asignatura".to_string()
    } else {
        trimmed.chars().take(80).collect()
    }
}

fn unique_path(directory: &Path, base: &str, extension: &str) -> PathBuf {
    let mut candidate = directory.join(format!("{base}.{extension}"));
    let mut suffix = 1_i64;
    while candidate.exists() {
        candidate = directory.join(format!("{base}-{suffix}.{extension}"));
        suffix += 1;
    }
    candidate
}

fn timestamp_label() -> String {
    Utc::now().format("%Y%m%d-%H%M%S").to_string()
}

fn now_rfc3339() -> String {
    Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true)
}

fn data_root() -> PathBuf {
    db::data_directory().unwrap_or_else(|| std::env::temp_dir().join("study_planner"))
}

fn documents_root() -> PathBuf {
    data_root().join("documents")
}

fn read_entry(archive: &mut ZipArchive<File>, name: &str) -> CoreResult<Vec<u8>> {
    let mut entry = archive.by_name(name).map_err(zip_error)?;
    let mut bytes = Vec::new();
    entry.read_to_end(&mut bytes)?;
    Ok(bytes)
}

fn load_manifest(archive: &mut ZipArchive<File>) -> CoreResult<(Manifest, Integrity)> {
    let manifest_bytes = read_entry(archive, MANIFEST_ENTRY)?;
    let integrity_bytes = read_entry(archive, INTEGRITY_ENTRY)?;
    let integrity: Integrity = serde_json::from_slice(&integrity_bytes).map_err(json_error)?;
    if hash_bytes(&manifest_bytes) != integrity.manifest_sha256 {
        return Err(CoreError::Validation(
            "la copia está dañada: el manifiesto no coincide con su huella".into(),
        ));
    }
    let manifest: Manifest = serde_json::from_slice(&manifest_bytes).map_err(json_error)?;
    if manifest.format_version != FORMAT_VERSION {
        return Err(CoreError::Validation(format!(
            "versión de copia no soportada: {}",
            manifest.format_version
        )));
    }
    Ok((manifest, integrity))
}

fn verify_entry(
    archive: &mut ZipArchive<File>,
    integrity: &Integrity,
    document: &DocumentRecord,
    target: &Path,
) -> CoreResult<()> {
    let archive_path = document.archive_path.as_deref().ok_or_else(|| {
        CoreError::Validation(format!(
            "el documento «{}» no tiene archivo empaquetado",
            document.name
        ))
    })?;
    let expected = integrity.files.get(archive_path).ok_or_else(|| {
        CoreError::Validation(format!(
            "el documento «{}» no figura en la verificación de integridad",
            document.name
        ))
    })?;
    if document.file_sha256.as_deref() != Some(expected.as_str()) {
        return Err(CoreError::Validation(format!(
            "la huella del documento «{}» no coincide con el manifiesto",
            document.name
        )));
    }
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent)?;
    }
    let mut entry = archive.by_name(archive_path).map_err(zip_error)?;
    let mut file = File::create(target)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0_u8; COPY_BUFFER];
    loop {
        let read = entry.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
        file.write_all(&buffer[..read])?;
    }
    file.flush()?;
    let actual = hex::encode(hasher.finalize());
    if &actual != expected {
        let _ = fs::remove_file(target);
        return Err(CoreError::Validation(format!(
            "el archivo del documento «{}» está dañado",
            document.name
        )));
    }
    Ok(())
}

pub fn export_study_plan(
    database: &mut Database,
    subject_id: i64,
    directory: &str,
) -> CoreResult<ExportResult> {
    let directory = Path::new(directory);
    fs::create_dir_all(directory)?;
    let subject = collect_subject(database.connection(), subject_id)?;
    let profile = database
        .connection()
        .query_row(
            "SELECT id, nombre, config_json, created_at FROM profiles WHERE id = ?1",
            params![subject.profile_old_id],
            |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, String>(3)?,
                ))
            },
        )
        .optional()?
        .ok_or_else(|| CoreError::NotFound(format!("perfil {}", subject.profile_old_id)))?;

    let mut activity_filter = HashSet::new();
    for session in &subject.sessions {
        activity_filter.insert(format!("sesion:{}", session.old_id));
    }
    for topic in &subject.topics {
        activity_filter.insert(format!("dominar_tema:{}", topic.old_id));
    }
    let profile_record = collect_profile(
        database.connection(),
        profile.0,
        &profile.1,
        &profile.2,
        &profile.3,
        Some(&activity_filter),
        false,
    )?;
    let change_ids = subject_change_ids(&subject);
    let changes = collect_changes(database.connection(), Some(&change_ids))?;

    let mut manifest = Manifest {
        format: FORMAT_STUDY_PLAN.to_string(),
        format_version: FORMAT_VERSION,
        exported_at: now_rfc3339(),
        profiles: vec![profile_record],
        subjects: vec![subject],
        changes,
    };
    let counts = counts_for(&manifest);
    let path = unique_path(
        directory,
        &sanitize_name(&manifest.subjects[0].name),
        "studyplan",
    );
    write_package(&mut manifest, &path)?;
    let bytes = fs::metadata(&path)?.len() as i64;
    let checksum = hash_file(&path)?;
    Ok(ExportResult {
        path: path.to_string_lossy().to_string(),
        bytes,
        checksum,
        counts,
        message: format!(
            "Asignatura exportada con {} temas y {} documentos.",
            manifest.subjects[0].topics.len(),
            manifest.subjects[0].documents.len()
        ),
    })
}

pub fn export_backup(database: &mut Database, directory: &str) -> CoreResult<ExportResult> {
    let directory = Path::new(directory);
    fs::create_dir_all(directory)?;
    let conn = database.connection();
    let mut profiles = Vec::new();
    {
        let mut stmt = conn
            .prepare("SELECT id, nombre, config_json, created_at FROM profiles ORDER BY id ASC")?;
        let rows = stmt.query_map([], |row| {
            Ok((
                row.get::<_, i64>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
                row.get::<_, String>(3)?,
            ))
        })?;
        for row in rows {
            let (id, name, config_json, created_at) = row?;
            profiles.push(collect_profile(
                conn,
                id,
                &name,
                &config_json,
                &created_at,
                None,
                true,
            )?);
        }
    }
    let mut subjects = Vec::new();
    {
        let mut stmt = conn.prepare("SELECT id FROM subjects ORDER BY id ASC")?;
        let rows = stmt.query_map([], |row| row.get::<_, i64>(0))?;
        for row in rows {
            subjects.push(collect_subject(conn, row?)?);
        }
    }
    let changes = collect_changes(conn, None)?;
    let mut manifest = Manifest {
        format: FORMAT_BACKUP.to_string(),
        format_version: FORMAT_VERSION,
        exported_at: now_rfc3339(),
        profiles,
        subjects,
        changes,
    };
    let counts = counts_for(&manifest);
    let path = unique_path(
        directory,
        &format!("copia-global-{}", timestamp_label()),
        "studybackup",
    );
    write_package(&mut manifest, &path)?;
    let bytes = fs::metadata(&path)?.len() as i64;
    let checksum = hash_file(&path)?;
    Ok(ExportResult {
        path: path.to_string_lossy().to_string(),
        bytes,
        checksum,
        counts,
        message: format!(
            "Copia global exportada con {} perfiles y {} asignaturas.",
            manifest.profiles.len(),
            manifest.subjects.len()
        ),
    })
}

fn write_package(manifest: &mut Manifest, path: &Path) -> CoreResult<()> {
    let file = File::create(path)?;
    let mut archive = ZipWriter::new(file);
    let options = SimpleFileOptions::default()
        .compression_method(CompressionMethod::Deflated)
        .unix_permissions(0o644);
    let mut files = BTreeMap::new();
    for subject in &mut manifest.subjects {
        for document in &mut subject.documents {
            let Some(source) = document.source_path.take() else {
                document.archive_path = None;
                document.file_sha256 = None;
                continue;
            };
            if !source.is_file() {
                document.archive_path = None;
                document.file_sha256 = None;
                continue;
            }
            let Some(archive_path) = document.archive_path.clone() else {
                document.file_sha256 = None;
                continue;
            };
            archive
                .start_file(&archive_path, options)
                .map_err(zip_error)?;
            let mut source_file = File::open(&source)?;
            let mut hasher = Sha256::new();
            let mut buffer = [0_u8; COPY_BUFFER];
            loop {
                let read = source_file.read(&mut buffer)?;
                if read == 0 {
                    break;
                }
                hasher.update(&buffer[..read]);
                archive.write_all(&buffer[..read])?;
            }
            let digest = hex::encode(hasher.finalize());
            document.file_sha256 = Some(digest.clone());
            files.insert(archive_path, digest);
        }
    }
    let manifest_bytes = serde_json::to_vec_pretty(&*manifest).map_err(json_error)?;
    archive
        .start_file(MANIFEST_ENTRY, options)
        .map_err(zip_error)?;
    archive.write_all(&manifest_bytes)?;
    let integrity = Integrity {
        manifest_sha256: hash_bytes(&manifest_bytes),
        files,
    };
    let integrity_bytes = serde_json::to_vec_pretty(&integrity).map_err(json_error)?;
    archive
        .start_file(INTEGRITY_ENTRY, options)
        .map_err(zip_error)?;
    archive.write_all(&integrity_bytes)?;
    archive.finish().map_err(zip_error)?;
    Ok(())
}

pub fn inspect_study_plan(
    database: &Database,
    path: &str,
    profile_id: i64,
) -> CoreResult<StudyPlanPreview> {
    let file = File::open(path)?;
    let mut archive = ZipArchive::new(file).map_err(zip_error)?;
    let (manifest, _) = load_manifest(&mut archive)?;
    if manifest.format != FORMAT_STUDY_PLAN {
        return Err(CoreError::Validation(
            "el archivo no es una asignatura .studyplan".into(),
        ));
    }
    let subject = manifest
        .subjects
        .first()
        .ok_or_else(|| CoreError::Validation("la copia no contiene asignaturas".into()))?;
    let profile_name = manifest
        .profiles
        .first()
        .map(|profile| profile.name.clone())
        .unwrap_or_default();
    let conflict = database
        .connection()
        .query_row(
            "SELECT 1 FROM subjects WHERE profile_id = ?1 AND nombre = ?2",
            params![profile_id, subject.name],
            |_| Ok(true),
        )
        .optional()?
        .unwrap_or(false);
    let message = if conflict {
        format!(
            "Ya existe una asignatura llamada «{}» en este perfil. Al continuar se reemplazará.",
            subject.name
        )
    } else {
        format!("Listo para importar «{}».", subject.name)
    };
    Ok(StudyPlanPreview {
        subject_name: subject.name.clone(),
        profile_name,
        counts: counts_for(&manifest),
        conflict,
        message,
    })
}

pub fn import_study_plan(
    database: &mut Database,
    path: &str,
    profile_id: i64,
    overwrite: bool,
) -> CoreResult<StudyPlanImport> {
    let file = File::open(path)?;
    let mut archive = ZipArchive::new(file).map_err(zip_error)?;
    let (manifest, integrity) = load_manifest(&mut archive)?;
    if manifest.format != FORMAT_STUDY_PLAN {
        return Err(CoreError::Validation(
            "el archivo no es una asignatura .studyplan".into(),
        ));
    }
    let subject = manifest
        .subjects
        .first()
        .ok_or_else(|| CoreError::Validation("la copia no contiene asignaturas".into()))?
        .clone();
    let profile_name: Option<String> = database
        .connection()
        .query_row(
            "SELECT nombre FROM profiles WHERE id = ?1",
            params![profile_id],
            |row| row.get(0),
        )
        .optional()?;
    if profile_name.is_none() {
        return Err(CoreError::NotFound(format!("perfil {profile_id}")));
    }
    let conflict = database
        .connection()
        .query_row(
            "SELECT 1 FROM subjects WHERE profile_id = ?1 AND nombre = ?2",
            params![profile_id, subject.name],
            |_| Ok(true),
        )
        .optional()?
        .unwrap_or(false);
    let counts = counts_for(&manifest);
    if conflict && !overwrite {
        return Ok(StudyPlanImport {
            subject_id: 0,
            subject_name: subject.name.clone(),
            profile_id,
            counts,
            requires_confirmation: true,
            message: format!(
                "Ya existe una asignatura llamada «{}». Confirma para reemplazarla.",
                subject.name
            ),
        });
    }

    let staging = documents_root().join(format!(
        "import-{}-{}",
        profile_id,
        Utc::now().timestamp_millis()
    ));
    fs::create_dir_all(&staging)?;
    let result = (|| -> CoreResult<i64> {
        let tx = database.connection_mut().transaction()?;
        if conflict {
            tx.execute(
                "DELETE FROM subjects WHERE profile_id = ?1 AND nombre = ?2",
                params![profile_id, subject.name],
            )?;
        }
        let maps = insert_subject(
            &tx,
            &mut archive,
            &integrity,
            &subject,
            profile_id,
            &staging,
        )?;
        insert_profile_activity(&tx, &manifest, profile_id, &[&maps], false, &HashMap::new())?;
        insert_changes(
            &tx,
            &manifest.changes,
            profile_id,
            &[&maps],
            &HashMap::new(),
        )?;
        tx.execute(
            "INSERT INTO change_history (entidad, entidad_id, accion, timestamp)
             VALUES ('subject', ?1, 'importar', ?2)",
            params![maps.subject_id, now_rfc3339()],
        )?;
        tx.commit()?;
        Ok(maps.subject_id)
    })();
    let subject_id = match result {
        Ok(id) => id,
        Err(error) => {
            let _ = fs::remove_dir_all(&staging);
            return Err(error);
        }
    };
    Ok(StudyPlanImport {
        subject_id,
        subject_name: subject.name,
        profile_id,
        counts,
        requires_confirmation: false,
        message: "Asignatura importada correctamente.".to_string(),
    })
}

pub fn inspect_backup(database: &Database, path: &str) -> CoreResult<BackupPreview> {
    let file = File::open(path)?;
    let mut archive = ZipArchive::new(file).map_err(zip_error)?;
    let (manifest, _) = load_manifest(&mut archive)?;
    if manifest.format != FORMAT_BACKUP {
        return Err(CoreError::Validation(
            "el archivo no es una copia global .studybackup".into(),
        ));
    }
    let existing: i64 =
        database
            .connection()
            .query_row("SELECT COUNT(*) FROM profiles", [], |row| row.get(0))?;
    let conflict = existing > 0;
    let message = if conflict {
        "Ya existen perfiles en este dispositivo. Restaurar reemplazará todos los datos actuales."
            .to_string()
    } else {
        "Listo para restaurar la copia global.".to_string()
    };
    Ok(BackupPreview {
        profile_names: manifest
            .profiles
            .iter()
            .map(|profile| profile.name.clone())
            .collect(),
        counts: counts_for(&manifest),
        conflict,
        message,
    })
}

pub fn restore_backup(
    database: &mut Database,
    path: &str,
    overwrite: bool,
) -> CoreResult<BackupRestore> {
    let file = File::open(path)?;
    let mut archive = ZipArchive::new(file).map_err(zip_error)?;
    let (manifest, integrity) = load_manifest(&mut archive)?;
    if manifest.format != FORMAT_BACKUP {
        return Err(CoreError::Validation(
            "el archivo no es una copia global .studybackup".into(),
        ));
    }
    let existing: i64 =
        database
            .connection()
            .query_row("SELECT COUNT(*) FROM profiles", [], |row| row.get(0))?;
    let counts = counts_for(&manifest);
    if existing > 0 && !overwrite {
        return Ok(BackupRestore {
            counts,
            requires_confirmation: true,
            message: "Ya existen perfiles. Confirma para reemplazar todos los datos.".to_string(),
        });
    }

    let staging = documents_root().join(format!("restore-{}", Utc::now().timestamp_millis()));
    fs::create_dir_all(&staging)?;
    let result = (|| -> CoreResult<()> {
        let tx = database.connection_mut().transaction()?;
        if existing > 0 {
            tx.execute("DELETE FROM change_history", [])?;
            tx.execute("DELETE FROM profiles", [])?;
        }
        let mut profile_map = HashMap::new();
        for profile in &manifest.profiles {
            let name = profile.name.trim();
            if name.is_empty() {
                return Err(CoreError::Validation(
                    "la copia contiene un perfil sin nombre".into(),
                ));
            }
            tx.execute(
                "INSERT INTO profiles (nombre, config_json, created_at)
                 VALUES (?1, ?2, ?3)",
                params![name, profile.config_json, profile.created_at],
            )?;
            let new_id = tx.last_insert_rowid();
            profile_map.insert(profile.old_id, new_id);
        }
        let mut subject_maps = Vec::new();
        for subject in &manifest.subjects {
            let new_profile_id = *profile_map.get(&subject.profile_old_id).ok_or_else(|| {
                CoreError::Validation(format!(
                    "la asignatura «{}» referencia un perfil inexistente",
                    subject.name
                ))
            })?;
            let maps = insert_subject(
                &tx,
                &mut archive,
                &integrity,
                subject,
                new_profile_id,
                &staging,
            )?;
            subject_maps.push(maps);
        }
        let subject_refs: Vec<&SubjectIdMaps> = subject_maps.iter().collect();
        for profile in &manifest.profiles {
            let new_profile_id = *profile_map
                .get(&profile.old_id)
                .ok_or_else(|| CoreError::Validation("perfil sin mapear".into()))?;
            if let Some(streak) = &profile.streak {
                tx.execute(
                    "INSERT INTO streaks
                        (profile_id, current_days, best_days, last_activity_date,
                         freeze_enabled, freeze_used_on)
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
                    params![
                        new_profile_id,
                        streak.current_days,
                        streak.best_days,
                        streak.last_activity_date,
                        streak.freeze_enabled,
                        streak.freeze_used_on
                    ],
                )?;
            }
        }
        insert_profile_activity(
            &tx,
            &manifest,
            new_profile_id_for(&manifest, &profile_map)?,
            &subject_refs,
            true,
            &profile_map,
        )?;
        insert_changes(
            &tx,
            &manifest.changes,
            new_profile_id_for(&manifest, &profile_map)?,
            &subject_refs,
            &profile_map,
        )?;
        tx.commit()?;
        Ok(())
    })();
    if let Err(error) = result {
        let _ = fs::remove_dir_all(&staging);
        return Err(error);
    }
    Ok(BackupRestore {
        counts,
        requires_confirmation: false,
        message: "Copia global restaurada correctamente.".to_string(),
    })
}

fn new_profile_id_for(manifest: &Manifest, profile_map: &HashMap<i64, i64>) -> CoreResult<i64> {
    manifest
        .profiles
        .first()
        .and_then(|profile| profile_map.get(&profile.old_id).copied())
        .ok_or_else(|| CoreError::Validation("la copia no contiene perfiles".into()))
}

fn insert_profile_activity(
    tx: &Transaction<'_>,
    manifest: &Manifest,
    target_profile_id: i64,
    subject_maps: &[&SubjectIdMaps],
    all_profiles: bool,
    profile_map: &HashMap<i64, i64>,
) -> CoreResult<()> {
    for profile in &manifest.profiles {
        let profile_id = if all_profiles {
            *profile_map
                .get(&profile.old_id)
                .ok_or_else(|| CoreError::Validation("perfil sin mapear".into()))?
        } else {
            target_profile_id
        };
        for entry in &profile.xp_log {
            let activity = remap_activity(&entry.activity, subject_maps);
            tx.execute(
                "INSERT INTO xp_log (profile_id, actividad, xp, timestamp)
                 VALUES (?1, ?2, ?3, ?4)",
                params![profile_id, activity, entry.xp, entry.timestamp],
            )?;
        }
    }
    Ok(())
}

fn remap_activity(activity: &str, subject_maps: &[&SubjectIdMaps]) -> String {
    if let Some(value) = activity.strip_prefix("sesion:") {
        if let Ok(old_id) = value.parse::<i64>() {
            for maps in subject_maps {
                if let Some(new_id) = maps.sessions.get(&old_id) {
                    return format!("sesion:{new_id}");
                }
            }
        }
    }
    if let Some(value) = activity.strip_prefix("dominar_tema:") {
        if let Ok(old_id) = value.parse::<i64>() {
            for maps in subject_maps {
                if let Some(new_id) = maps.topics.get(&old_id) {
                    return format!("dominar_tema:{new_id}");
                }
            }
        }
    }
    activity.to_string()
}

fn insert_changes(
    tx: &Transaction<'_>,
    changes: &[ChangeRecord],
    target_profile_id: i64,
    subject_maps: &[&SubjectIdMaps],
    profile_map: &HashMap<i64, i64>,
) -> CoreResult<()> {
    for change in changes {
        let new_id = match change.entity.as_str() {
            "profile" => profile_map
                .get(&change.entity_old_id)
                .copied()
                .or(Some(target_profile_id)),
            "subject" => subject_maps
                .iter()
                .find(|maps| maps.old_subject_id == change.entity_old_id)
                .map(|maps| maps.subject_id),
            "topic" => subject_maps
                .iter()
                .find_map(|maps| maps.topics.get(&change.entity_old_id).copied()),
            "document" => subject_maps
                .iter()
                .find_map(|maps| maps.documents.get(&change.entity_old_id).copied()),
            "session" => subject_maps
                .iter()
                .find_map(|maps| maps.sessions.get(&change.entity_old_id).copied()),
            "flashcard" => subject_maps
                .iter()
                .find_map(|maps| maps.flashcards.get(&change.entity_old_id).copied()),
            "assessment" => subject_maps
                .iter()
                .find_map(|maps| maps.assessments.get(&change.entity_old_id).copied()),
            _ => None,
        };
        let Some(entity_id) = new_id else {
            continue;
        };
        tx.execute(
            "INSERT INTO change_history (entidad, entidad_id, accion, timestamp)
             VALUES (?1, ?2, ?3, ?4)",
            params![change.entity, entity_id, change.action, change.timestamp],
        )?;
    }
    Ok(())
}

fn insert_subject(
    tx: &Transaction<'_>,
    archive: &mut ZipArchive<File>,
    integrity: &Integrity,
    subject: &SubjectRecord,
    profile_id: i64,
    staging: &Path,
) -> CoreResult<SubjectIdMaps> {
    let name = subject.name.trim();
    if name.is_empty() {
        return Err(CoreError::Validation(
            "la copia contiene una asignatura sin nombre".into(),
        ));
    }
    tx.execute(
        "INSERT INTO subjects (profile_id, nombre, color, xp_config_json, created_at)
         VALUES (?1, ?2, ?3, ?4, ?5)",
        params![
            profile_id,
            name,
            subject.color,
            subject.xp_config_json,
            subject.created_at
        ],
    )?;
    let subject_id = tx.last_insert_rowid();
    let mut maps = SubjectIdMaps {
        old_subject_id: subject.old_id,
        subject_id,
        ..SubjectIdMaps::default()
    };

    for topic in &subject.topics {
        tx.execute(
            "INSERT INTO topics
                (subject_id, parent_id, nombre, dificultad, dominio, created_at)
             VALUES (?1, NULL, ?2, ?3, ?4, ?5)",
            params![
                subject_id,
                topic.name,
                topic.difficulty,
                topic.mastery,
                topic.created_at
            ],
        )?;
        maps.topics.insert(topic.old_id, tx.last_insert_rowid());
    }
    for topic in &subject.topics {
        if let Some(parent_old_id) = topic.parent_old_id {
            if let (Some(new_id), Some(new_parent_id)) = (
                maps.topics.get(&topic.old_id).copied(),
                maps.topics.get(&parent_old_id).copied(),
            ) {
                tx.execute(
                    "UPDATE topics SET parent_id = ?1 WHERE id = ?2",
                    params![new_parent_id, new_id],
                )?;
            }
        }
    }

    for document in &subject.documents {
        tx.execute(
            "INSERT INTO documents
                (subject_id, nombre, ruta_local, tipo, hash, version, created_at,
                 extraccion_estado, extraccion_mensaje)
             VALUES (?1, ?2, '', ?3, ?4, ?5, ?6, ?7, ?8)",
            params![
                subject_id,
                document.name,
                document.kind,
                document.hash,
                document.version,
                document.created_at,
                document.extraction_status,
                document.extraction_message
            ],
        )?;
        let document_id = tx.last_insert_rowid();
        maps.documents.insert(document.old_id, document_id);
        for chunk in &document.chunks {
            tx.execute(
                "INSERT INTO document_chunks (document_id, texto, seccion)
                 VALUES (?1, ?2, ?3)",
                params![document_id, chunk.text, chunk.section],
            )?;
        }
        if document.archive_path.is_some() {
            let file_name = format!("{}-{}", document_id, sanitize_name(&document.name));
            let target = staging.join(file_name);
            verify_entry(archive, integrity, document, &target)?;
            tx.execute(
                "UPDATE documents SET ruta_local = ?1 WHERE id = ?2",
                params![target.to_string_lossy().to_string(), document_id],
            )?;
        }
    }

    for session in &subject.sessions {
        let topic_id = session
            .topic_old_id
            .and_then(|old_id| maps.topics.get(&old_id).copied());
        tx.execute(
            "INSERT INTO sessions
                (subject_id, topic_id, inicio, duracion_min, estado, inicio_original)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                subject_id,
                topic_id,
                session.start,
                session.duration_min,
                session.state,
                session.original_start
            ],
        )?;
        maps.sessions.insert(session.old_id, tx.last_insert_rowid());
    }

    for flashcard in &subject.flashcards {
        let topic_id = maps
            .topics
            .get(&flashcard.topic_old_id)
            .copied()
            .ok_or_else(|| {
                CoreError::Validation(format!(
                    "la tarjeta «{}» referencia un tema inexistente",
                    flashcard.question
                ))
            })?;
        tx.execute(
            "INSERT INTO flashcards
                (topic_id, pregunta, respuesta, intervalo_dias, proxima_revision,
                 created_at, repasos, factor_facilidad, ultima_revision, origen)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
            params![
                topic_id,
                flashcard.question,
                flashcard.answer,
                flashcard.interval_days,
                flashcard.next_review,
                flashcard.created_at,
                flashcard.repetitions,
                flashcard.ease_factor,
                flashcard.last_review,
                flashcard.origin
            ],
        )?;
        maps.flashcards
            .insert(flashcard.old_id, tx.last_insert_rowid());
    }

    for review in &subject.reviews {
        let flashcard_id = maps
            .flashcards
            .get(&review.flashcard_old_id)
            .copied()
            .ok_or_else(|| CoreError::Validation("repaso sin tarjeta".into()))?;
        let topic_id = maps
            .topics
            .get(&review.topic_old_id)
            .copied()
            .ok_or_else(|| CoreError::Validation("repaso sin tema".into()))?;
        tx.execute(
            "INSERT INTO review_log
                (flashcard_id, topic_id, calidad, intervalo_dias,
                 factor_facilidad, timestamp)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params![
                flashcard_id,
                topic_id,
                review.quality,
                review.interval_days,
                review.ease_factor,
                review.timestamp
            ],
        )?;
    }

    for assessment in &subject.assessments {
        tx.execute(
            "INSERT INTO assessments (subject_id, tipo, puntuacion, fecha)
             VALUES (?1, ?2, ?3, ?4)",
            params![
                subject_id,
                assessment.kind,
                assessment.score,
                assessment.date
            ],
        )?;
        maps.assessments
            .insert(assessment.old_id, tx.last_insert_rowid());
    }

    if let Some(settings) = &subject.plan_settings {
        tx.execute(
            "INSERT INTO plan_settings
                (subject_id, duracion_sesion_min, hora_inicio, fecha_limite, actualizado_en)
             VALUES (?1, ?2, ?3, ?4, ?5)",
            params![
                subject_id,
                settings.session_minutes,
                settings.start_hour,
                settings.deadline,
                settings.updated_at
            ],
        )?;
    }
    for day in &subject.availability {
        tx.execute(
            "INSERT INTO availability (subject_id, dia_semana, minutos)
             VALUES (?1, ?2, ?3)",
            params![subject_id, day.weekday, day.minutes],
        )?;
    }

    Ok(maps)
}

fn collect_profile(
    conn: &Connection,
    profile_id: i64,
    name: &str,
    config_json: &str,
    created_at: &str,
    activity_filter: Option<&HashSet<String>>,
    include_streak: bool,
) -> CoreResult<ProfileRecord> {
    let mut xp_log = Vec::new();
    let mut stmt = conn.prepare(
        "SELECT id, actividad, xp, timestamp FROM xp_log
         WHERE profile_id = ?1 ORDER BY id ASC",
    )?;
    let rows = stmt.query_map(params![profile_id], |row| {
        Ok(XpLogRecord {
            old_id: row.get(0)?,
            activity: row.get(1)?,
            xp: row.get(2)?,
            timestamp: row.get(3)?,
        })
    })?;
    for row in rows {
        let entry = row?;
        if activity_filter
            .map(|filter| filter.contains(&entry.activity))
            .unwrap_or(true)
        {
            xp_log.push(entry);
        }
    }
    let streak = if include_streak {
        conn.query_row(
            "SELECT current_days, best_days, last_activity_date,
                    freeze_enabled, freeze_used_on
             FROM streaks WHERE profile_id = ?1",
            params![profile_id],
            |row| {
                Ok(StreakRecord {
                    current_days: row.get(0)?,
                    best_days: row.get(1)?,
                    last_activity_date: row.get(2)?,
                    freeze_enabled: row.get(3)?,
                    freeze_used_on: row.get(4)?,
                })
            },
        )
        .optional()?
    } else {
        None
    };
    Ok(ProfileRecord {
        old_id: profile_id,
        name: name.to_string(),
        config_json: config_json.to_string(),
        created_at: created_at.to_string(),
        xp_log,
        streak,
    })
}

fn collect_subject(conn: &Connection, subject_id: i64) -> CoreResult<SubjectRecord> {
    let (old_id, profile_old_id, name, color, xp_config_json, created_at) = conn
        .query_row(
            "SELECT id, profile_id, nombre, color, xp_config_json, created_at
             FROM subjects WHERE id = ?1",
            params![subject_id],
            |row| {
                Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, i64>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, String>(3)?,
                    row.get::<_, String>(4)?,
                    row.get::<_, String>(5)?,
                ))
            },
        )
        .optional()?
        .ok_or_else(|| CoreError::NotFound(format!("asignatura {subject_id}")))?;

    let mut topics = Vec::new();
    {
        let mut stmt = conn.prepare(
            "SELECT id, parent_id, nombre, dificultad, dominio, created_at
             FROM topics WHERE subject_id = ?1 ORDER BY id ASC",
        )?;
        let rows = stmt.query_map(params![subject_id], |row| {
            Ok(TopicRecord {
                old_id: row.get(0)?,
                parent_old_id: row.get(1)?,
                name: row.get(2)?,
                difficulty: row.get(3)?,
                mastery: row.get(4)?,
                created_at: row.get(5)?,
            })
        })?;
        for row in rows {
            topics.push(row?);
        }
    }

    let mut documents = Vec::new();
    {
        let mut stmt = conn.prepare(
            "SELECT id, nombre, ruta_local, tipo, hash, version, created_at,
                    extraccion_estado, extraccion_mensaje
             FROM documents WHERE subject_id = ?1 ORDER BY id ASC",
        )?;
        let rows = stmt.query_map(params![subject_id], |row| {
            Ok(DocumentRecord {
                old_id: row.get(0)?,
                name: row.get(1)?,
                local_path: row.get(2)?,
                kind: row.get(3)?,
                hash: row.get(4)?,
                version: row.get(5)?,
                created_at: row.get(6)?,
                extraction_status: row.get(7)?,
                extraction_message: row.get(8)?,
                chunks: Vec::new(),
                archive_path: None,
                file_sha256: None,
                source_path: None,
            })
        })?;
        for row in rows {
            let mut document = row?;
            let source = PathBuf::from(&document.local_path);
            if source.is_file() {
                document.archive_path = Some(format!(
                    "documents/{}/{}-{}",
                    subject_id,
                    document.old_id,
                    sanitize_name(&document.name)
                ));
                document.source_path = Some(source);
            }
            let mut chunks_stmt = conn.prepare(
                "SELECT texto, seccion FROM document_chunks
                 WHERE document_id = ?1 ORDER BY id ASC",
            )?;
            let chunk_rows = chunks_stmt.query_map(params![document.old_id], |row| {
                Ok(ChunkRecord {
                    text: row.get(0)?,
                    section: row.get(1)?,
                })
            })?;
            for chunk in chunk_rows {
                document.chunks.push(chunk?);
            }
            documents.push(document);
        }
    }

    let mut sessions = Vec::new();
    {
        let mut stmt = conn.prepare(
            "SELECT id, topic_id, inicio, duracion_min, estado, inicio_original
             FROM sessions WHERE subject_id = ?1 ORDER BY id ASC",
        )?;
        let rows = stmt.query_map(params![subject_id], |row| {
            Ok(SessionRecord {
                old_id: row.get(0)?,
                topic_old_id: row.get(1)?,
                start: row.get(2)?,
                duration_min: row.get(3)?,
                state: row.get(4)?,
                original_start: row.get(5)?,
            })
        })?;
        for row in rows {
            sessions.push(row?);
        }
    }

    let mut flashcards = Vec::new();
    {
        let mut stmt = conn.prepare(
            "SELECT f.id, f.topic_id, f.pregunta, f.respuesta, f.intervalo_dias,
                    f.proxima_revision, f.created_at, f.repasos, f.factor_facilidad,
                    f.ultima_revision, f.origen
             FROM flashcards f
             JOIN topics t ON t.id = f.topic_id
             WHERE t.subject_id = ?1 ORDER BY f.id ASC",
        )?;
        let rows = stmt.query_map(params![subject_id], |row| {
            Ok(FlashcardRecord {
                old_id: row.get(0)?,
                topic_old_id: row.get(1)?,
                question: row.get(2)?,
                answer: row.get(3)?,
                interval_days: row.get(4)?,
                next_review: row.get(5)?,
                created_at: row.get(6)?,
                repetitions: row.get(7)?,
                ease_factor: row.get(8)?,
                last_review: row.get(9)?,
                origin: row.get(10)?,
            })
        })?;
        for row in rows {
            flashcards.push(row?);
        }
    }

    let mut reviews = Vec::new();
    {
        let mut stmt = conn.prepare(
            "SELECT r.id, r.flashcard_id, r.topic_id, r.calidad, r.intervalo_dias,
                    r.factor_facilidad, r.timestamp
             FROM review_log r
             JOIN topics t ON t.id = r.topic_id
             WHERE t.subject_id = ?1 ORDER BY r.id ASC",
        )?;
        let rows = stmt.query_map(params![subject_id], |row| {
            Ok(ReviewRecord {
                old_id: row.get(0)?,
                flashcard_old_id: row.get(1)?,
                topic_old_id: row.get(2)?,
                quality: row.get(3)?,
                interval_days: row.get(4)?,
                ease_factor: row.get(5)?,
                timestamp: row.get(6)?,
            })
        })?;
        for row in rows {
            reviews.push(row?);
        }
    }

    let mut assessments = Vec::new();
    {
        let mut stmt = conn.prepare(
            "SELECT id, tipo, puntuacion, fecha FROM assessments
             WHERE subject_id = ?1 ORDER BY id ASC",
        )?;
        let rows = stmt.query_map(params![subject_id], |row| {
            Ok(AssessmentRecord {
                old_id: row.get(0)?,
                kind: row.get(1)?,
                score: row.get(2)?,
                date: row.get(3)?,
            })
        })?;
        for row in rows {
            assessments.push(row?);
        }
    }

    let plan_settings = conn
        .query_row(
            "SELECT duracion_sesion_min, hora_inicio, fecha_limite, actualizado_en
             FROM plan_settings WHERE subject_id = ?1",
            params![subject_id],
            |row| {
                Ok(PlanSettingsRecord {
                    session_minutes: row.get(0)?,
                    start_hour: row.get(1)?,
                    deadline: row.get(2)?,
                    updated_at: row.get(3)?,
                })
            },
        )
        .optional()?;

    let mut availability = Vec::new();
    {
        let mut stmt = conn.prepare(
            "SELECT dia_semana, minutos FROM availability
             WHERE subject_id = ?1 ORDER BY dia_semana ASC",
        )?;
        let rows = stmt.query_map(params![subject_id], |row| {
            Ok(AvailabilityRecord {
                weekday: row.get(0)?,
                minutes: row.get(1)?,
            })
        })?;
        for row in rows {
            availability.push(row?);
        }
    }

    Ok(SubjectRecord {
        old_id,
        profile_old_id,
        name,
        color,
        xp_config_json,
        created_at,
        plan_settings,
        availability,
        topics,
        documents,
        sessions,
        flashcards,
        reviews,
        assessments,
    })
}

struct SubjectChangeIds {
    subject: i64,
    topics: HashSet<i64>,
    documents: HashSet<i64>,
    sessions: HashSet<i64>,
    flashcards: HashSet<i64>,
    assessments: HashSet<i64>,
}

fn subject_change_ids(subject: &SubjectRecord) -> SubjectChangeIds {
    SubjectChangeIds {
        subject: subject.old_id,
        topics: subject.topics.iter().map(|item| item.old_id).collect(),
        documents: subject.documents.iter().map(|item| item.old_id).collect(),
        sessions: subject.sessions.iter().map(|item| item.old_id).collect(),
        flashcards: subject.flashcards.iter().map(|item| item.old_id).collect(),
        assessments: subject.assessments.iter().map(|item| item.old_id).collect(),
    }
}

fn collect_changes(
    conn: &Connection,
    filter: Option<&SubjectChangeIds>,
) -> CoreResult<Vec<ChangeRecord>> {
    let mut stmt = conn.prepare(
        "SELECT id, entidad, entidad_id, accion, timestamp
         FROM change_history ORDER BY id ASC",
    )?;
    let rows = stmt.query_map([], |row| {
        Ok(ChangeRecord {
            old_id: row.get(0)?,
            entity: row.get(1)?,
            entity_old_id: row.get(2)?,
            action: row.get(3)?,
            timestamp: row.get(4)?,
        })
    })?;
    let mut changes = Vec::new();
    for row in rows {
        let change = row?;
        let keep = match filter {
            None => true,
            Some(ids) => match change.entity.as_str() {
                "subject" => change.entity_old_id == ids.subject,
                "topic" => ids.topics.contains(&change.entity_old_id),
                "document" => ids.documents.contains(&change.entity_old_id),
                "session" => ids.sessions.contains(&change.entity_old_id),
                "flashcard" => ids.flashcards.contains(&change.entity_old_id),
                "assessment" => ids.assessments.contains(&change.entity_old_id),
                _ => false,
            },
        };
        if keep {
            changes.push(change);
        }
    }
    Ok(changes)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{AvailabilityDay, PlanSettings};

    fn temp_root(label: &str) -> PathBuf {
        let path = std::env::temp_dir().join(format!(
            "study_planner_backup_{label}_{}",
            Utc::now().timestamp_millis()
        ));
        fs::create_dir_all(&path).expect("carpeta temporal");
        path
    }

    fn setup(label: &str) -> (Database, PathBuf) {
        let mut database = Database::open_in_memory().expect("base en memoria");
        let root = temp_root(label);
        let profile = database.create_profile("Ana").expect("perfil");
        let subject = database
            .create_subject(profile.id, "Matemáticas", "#4F46E5")
            .expect("asignatura");
        let topic = database
            .create_topic(subject.id, "Álgebra", 1.2)
            .expect("tema");
        database
            .create_topic(subject.id, "Geometría", 1.5)
            .expect("tema");
        let document_path = root.join("apunte.txt");
        fs::write(&document_path, "Contenido de álgebra lineal").expect("archivo");
        crate::documents::import_document(
            &mut database,
            subject.id,
            &document_path.to_string_lossy(),
        )
        .expect("documento");
        database
            .create_flashcard(topic.id, "¿Qué es un vector?", "Una magnitud con dirección")
            .expect("tarjeta");
        let settings = PlanSettings {
            subject_id: subject.id,
            session_minutes: 45,
            start_hour: 9,
            deadline: "2026-12-01".to_string(),
            availability: vec![AvailabilityDay {
                weekday: 1,
                minutes: 120,
            }],
        };
        database.save_plan_settings(&settings).expect("ajustes");
        (database, root)
    }

    #[test]
    fn export_and_import_study_plan_preserves_data() {
        let (mut database, root) = setup("subject");
        let export_dir = root.join("export");
        fs::create_dir_all(&export_dir).expect("export");
        let subject_id = database.list_subjects(1).expect("asignaturas")[0].id;
        let exported = export_study_plan(&mut database, subject_id, &export_dir.to_string_lossy())
            .expect("exportar");
        assert!(Path::new(&exported.path).is_file());
        assert_eq!(exported.counts.subjects, 1);
        assert!(exported.counts.documents >= 1);

        let profile = database.create_profile("Luis").expect("perfil");
        let preview =
            inspect_study_plan(&database, &exported.path, profile.id).expect("previsualizar");
        assert!(!preview.conflict);
        let imported =
            import_study_plan(&mut database, &exported.path, profile.id, false).expect("importar");
        assert!(imported.subject_id > 0);
        assert!(!imported.requires_confirmation);
        let subjects = database.list_subjects(profile.id).expect("lista");
        assert_eq!(subjects.len(), 1);
        assert_eq!(subjects[0].name, "Matemáticas");
        let topics = database.list_topics(subjects[0].id).expect("temas");
        assert_eq!(topics.len(), 2);
        let documents = database.list_documents(subjects[0].id).expect("documentos");
        assert_eq!(documents.len(), 1);
        assert!(Path::new(&documents[0].local_path).is_file());
        let flashcards = database.list_flashcards(subjects[0].id).expect("tarjetas");
        assert_eq!(flashcards.len(), 1);
    }

    #[test]
    fn study_plan_imports_into_clean_database_preserving_history() {
        let (mut source, root) = setup("device_one");
        let export_dir = root.join("export");
        fs::create_dir_all(&export_dir).expect("export");
        let subject_id = source.list_subjects(1).expect("asignaturas")[0].id;
        let flashcard = source.list_flashcards(subject_id).expect("tarjetas")[0].clone();
        crate::learning::review_now(&mut source, flashcard.id, 5).expect("repaso");
        let exported = export_study_plan(&mut source, subject_id, &export_dir.to_string_lossy())
            .expect("exportar");

        let mut target = Database::open_in_memory().expect("dispositivo dos");
        let profile = target.create_profile("Luis").expect("perfil");
        let imported =
            import_study_plan(&mut target, &exported.path, profile.id, false).expect("importar");
        assert!(imported.subject_id > 0);

        let subject = target.get_subject(imported.subject_id).expect("asignatura");
        assert_eq!(subject.name, "Matemáticas");
        let topics = target.list_topics(subject.id).expect("temas");
        assert_eq!(topics.len(), 2);
        let documents = target.list_documents(subject.id).expect("documentos");
        assert_eq!(documents.len(), 1);
        assert!(Path::new(&documents[0].local_path).is_file());
        let cards = target.list_flashcards(subject.id).expect("tarjetas");
        assert_eq!(cards.len(), 1);
        let reviews: i64 = target
            .connection()
            .query_row(
                "SELECT COUNT(*) FROM review_log r
                 JOIN topics t ON t.id = r.topic_id
                 WHERE t.subject_id = ?1",
                params![subject.id],
                |row| row.get(0),
            )
            .expect("repasos");
        assert_eq!(reviews, 1);
        let chunks: i64 = target
            .connection()
            .query_row(
                "SELECT COUNT(*) FROM document_chunks c
                 JOIN documents d ON d.id = c.document_id
                 WHERE d.subject_id = ?1",
                params![subject.id],
                |row| row.get(0),
            )
            .expect("fragmentos");
        assert!(chunks >= 1);
        let settings = target.get_plan_settings(subject.id).expect("ajustes");
        assert_eq!(settings.session_minutes, 45);
        assert_eq!(settings.availability.len(), 1);
    }

    #[test]
    fn study_plan_conflict_requires_confirmation_and_can_replace() {
        let (mut database, root) = setup("conflict");
        let export_dir = root.join("export");
        fs::create_dir_all(&export_dir).expect("export");
        let subject_id = database.list_subjects(1).expect("asignaturas")[0].id;
        let exported = export_study_plan(&mut database, subject_id, &export_dir.to_string_lossy())
            .expect("exportar");
        let preview = inspect_study_plan(&database, &exported.path, 1).expect("previsualizar");
        assert!(preview.conflict);
        let pending =
            import_study_plan(&mut database, &exported.path, 1, false).expect("pendiente");
        assert!(pending.requires_confirmation);
        let imported =
            import_study_plan(&mut database, &exported.path, 1, true).expect("reemplazar");
        assert!(!imported.requires_confirmation);
        assert_eq!(database.list_subjects(1).expect("asignaturas").len(), 1);
    }

    #[test]
    fn backup_round_trip_restores_profiles_and_subjects() {
        let (mut database, root) = setup("backup");
        let export_dir = root.join("export");
        fs::create_dir_all(&export_dir).expect("export");
        let exported =
            export_backup(&mut database, &export_dir.to_string_lossy()).expect("exportar");
        assert!(Path::new(&exported.path).is_file());
        assert_eq!(exported.counts.profiles, 1);
        assert_eq!(exported.counts.subjects, 1);

        let mut clean = Database::open_in_memory().expect("limpia");
        let preview = inspect_backup(&clean, &exported.path).expect("previsualizar");
        assert!(!preview.conflict);
        assert_eq!(preview.profile_names, vec!["Ana".to_string()]);
        let restored = restore_backup(&mut clean, &exported.path, false).expect("restaurar");
        assert!(!restored.requires_confirmation);
        let profiles = clean.list_profiles().expect("perfiles");
        assert_eq!(profiles.len(), 1);
        let subjects = clean.list_subjects(profiles[0].id).expect("asignaturas");
        assert_eq!(subjects.len(), 1);
        assert_eq!(subjects[0].name, "Matemáticas");
    }

    #[test]
    fn restore_requires_confirmation_when_profiles_exist() {
        let (mut database, root) = setup("restore_conflict");
        let export_dir = root.join("export");
        fs::create_dir_all(&export_dir).expect("export");
        let exported =
            export_backup(&mut database, &export_dir.to_string_lossy()).expect("exportar");
        let pending = restore_backup(&mut database, &exported.path, false).expect("pendiente");
        assert!(pending.requires_confirmation);
        let restored = restore_backup(&mut database, &exported.path, true).expect("restaurar");
        assert!(!restored.requires_confirmation);
        assert_eq!(database.list_profiles().expect("perfiles").len(), 1);
    }

    #[test]
    fn corrupted_package_is_rejected() {
        let (mut database, root) = setup("corrupt");
        let export_dir = root.join("export");
        fs::create_dir_all(&export_dir).expect("export");
        let subject_id = database.list_subjects(1).expect("asignaturas")[0].id;
        let exported = export_study_plan(&mut database, subject_id, &export_dir.to_string_lossy())
            .expect("exportar");
        let bytes = fs::read(&exported.path).expect("leer");
        let mut corrupted = bytes.clone();
        let middle = corrupted.len() / 2;
        corrupted[middle] ^= 0xFF;
        let corrupted_path = export_dir.join("corrupto.studyplan");
        fs::write(&corrupted_path, corrupted).expect("escribir");
        let profile = database.create_profile("Otro").expect("perfil");
        let result = inspect_study_plan(&database, &corrupted_path.to_string_lossy(), profile.id);
        assert!(result.is_err());
    }
}
