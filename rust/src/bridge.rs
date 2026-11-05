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
