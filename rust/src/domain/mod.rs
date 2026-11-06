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

#[derive(Debug, Clone, PartialEq)]
pub struct Topic {
    pub id: i64,
    pub subject_id: i64,
    pub parent_id: Option<i64>,
    pub name: String,
    pub difficulty: f64,
    pub mastery: f64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AvailabilityDay {
    pub weekday: i64,
    pub minutes: i64,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanSettings {
    pub subject_id: i64,
    pub session_minutes: i64,
    pub start_hour: i64,
    pub deadline: String,
    pub availability: Vec<AvailabilityDay>,
}

impl PlanSettings {
    pub fn weekly_minutes(&self) -> i64 {
        self.availability.iter().map(|day| day.minutes).sum()
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlannedSession {
    pub topic_id: Option<i64>,
    pub topic_name: String,
    pub start: String,
    pub duration_min: i64,
    pub state: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanProposal {
    pub sessions: Vec<PlannedSession>,
    pub total_minutes: i64,
    pub weekly_minutes: i64,
    pub last_date: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Session {
    pub id: i64,
    pub subject_id: i64,
    pub topic_id: Option<i64>,
    pub topic_name: Option<String>,
    pub subject_name: String,
    pub subject_color: String,
    pub start: String,
    pub duration_min: i64,
    pub state: String,
    pub original_start: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ReplanResult {
    pub moved: i64,
    pub message: String,
}

pub mod defaults {
    pub const SUBJECT_COLOR: &str = "#4F46E5";
    pub const PROFILE_CONFIG: &str = "{}";
    pub const SUBJECT_XP_CONFIG: &str = "{}";
}
