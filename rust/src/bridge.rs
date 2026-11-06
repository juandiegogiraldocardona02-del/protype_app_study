use crate::db;
use crate::domain;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

#[derive(Debug, Clone)]
pub struct ProfileDto {
    pub id: i64,
    pub name: String,
    pub config_json: String,
}

#[derive(Debug, Clone)]
pub struct SubjectDto {
    pub id: i64,
    pub profile_id: i64,
    pub name: String,
    pub color: String,
    pub xp_config_json: String,
}

#[derive(Debug, Clone)]
pub struct DocumentDto {
    pub id: i64,
    pub subject_id: i64,
    pub name: String,
    pub local_path: String,
    pub kind: String,
    pub hash: String,
    pub version: i64,
    pub extraction_status: String,
    pub extraction_message: Option<String>,
    pub text_chars: i64,
}

#[derive(Debug, Clone)]
pub struct ImportOutcomeDto {
    pub document: DocumentDto,
    pub duplicate: bool,
    pub ocr_used: bool,
    pub message: String,
}

impl From<domain::Profile> for ProfileDto {
    fn from(value: domain::Profile) -> Self {
        Self {
            id: value.id,
            name: value.name,
            config_json: value.config_json,
        }
    }
}

impl From<domain::Subject> for SubjectDto {
    fn from(value: domain::Subject) -> Self {
        Self {
            id: value.id,
            profile_id: value.profile_id,
            name: value.name,
            color: value.color,
            xp_config_json: value.xp_config_json,
        }
    }
}

impl From<domain::Document> for DocumentDto {
    fn from(value: domain::Document) -> Self {
        Self {
            id: value.id,
            subject_id: value.subject_id,
            name: value.name,
            local_path: value.local_path,
            kind: value.kind,
            hash: value.hash,
            version: value.version,
            extraction_status: value.extraction_status,
            extraction_message: value.extraction_message,
            text_chars: value.text_chars,
        }
    }
}

impl From<domain::ImportOutcome> for ImportOutcomeDto {
    fn from(value: domain::ImportOutcome) -> Self {
        Self {
            document: value.document.into(),
            duplicate: value.duplicate,
            ocr_used: value.ocr_used,
            message: value.message,
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn initialize_database(path: String) -> anyhow::Result<()> {
    db::initialize(&path)?;
    Ok(())
}

pub fn list_profiles() -> anyhow::Result<Vec<ProfileDto>> {
    let profiles = db::with_db(|database| database.list_profiles())?;
    Ok(profiles.into_iter().map(ProfileDto::from).collect())
}

pub fn create_profile(name: String) -> anyhow::Result<ProfileDto> {
    let profile = db::with_db(|database| database.create_profile(&name))?;
    Ok(profile.into())
}

pub fn rename_profile(id: i64, name: String) -> anyhow::Result<ProfileDto> {
    let profile = db::with_db(|database| database.rename_profile(id, &name))?;
    Ok(profile.into())
}

pub fn delete_profile(id: i64) -> anyhow::Result<()> {
    db::with_db(|database| database.delete_profile(id))?;
    Ok(())
}

pub fn list_subjects(profile_id: i64) -> anyhow::Result<Vec<SubjectDto>> {
    let subjects = db::with_db(|database| database.list_subjects(profile_id))?;
    Ok(subjects.into_iter().map(SubjectDto::from).collect())
}

pub fn create_subject(profile_id: i64, name: String, color: String) -> anyhow::Result<SubjectDto> {
    let subject = db::with_db(|database| database.create_subject(profile_id, &name, &color))?;
    Ok(subject.into())
}

pub fn update_subject(id: i64, name: String, color: String) -> anyhow::Result<SubjectDto> {
    let subject = db::with_db(|database| database.update_subject(id, &name, &color))?;
    Ok(subject.into())
}

pub fn delete_subject(id: i64) -> anyhow::Result<()> {
    db::with_db(|database| database.delete_subject(id))?;
    Ok(())
}

pub fn import_document(subject_id: i64, path: String) -> anyhow::Result<ImportOutcomeDto> {
    let outcome =
        db::with_db(|database| crate::documents::import_document(database, subject_id, &path))?;
    Ok(outcome.into())
}

pub fn list_documents(subject_id: i64) -> anyhow::Result<Vec<DocumentDto>> {
    let documents = db::with_db(|database| crate::documents::list_documents(database, subject_id))?;
    Ok(documents.into_iter().map(DocumentDto::from).collect())
}

pub fn delete_document(id: i64) -> anyhow::Result<()> {
    db::with_db(|database| crate::documents::delete_document(database, id))?;
    Ok(())
}

pub fn ocr_available() -> bool {
    crate::documents::ocr_available()
}
