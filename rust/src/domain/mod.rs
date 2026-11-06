use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Profile {
    pub id: i64,
    pub name: String,
    pub config_json: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Subject {
    pub id: i64,
    pub profile_id: i64,
    pub name: String,
    pub color: String,
    pub xp_config_json: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Document {
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ImportOutcome {
    pub document: Document,
    pub duplicate: bool,
    pub ocr_used: bool,
    pub message: String,
}

pub mod defaults {
    pub const SUBJECT_COLOR: &str = "#4F46E5";
    pub const PROFILE_CONFIG: &str = "{}";
    pub const SUBJECT_XP_CONFIG: &str = "{}";
}
