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

#[derive(Debug, Clone)]
pub struct TopicDto {
    pub id: i64,
    pub subject_id: i64,
    pub parent_id: Option<i64>,
    pub name: String,
    pub difficulty: f64,
    pub mastery: f64,
}

#[derive(Debug, Clone)]
pub struct AvailabilityDayDto {
    pub weekday: i64,
    pub minutes: i64,
}

#[derive(Debug, Clone)]
pub struct PlanSettingsDto {
    pub subject_id: i64,
    pub session_minutes: i64,
    pub start_hour: i64,
    pub deadline: String,
    pub availability: Vec<AvailabilityDayDto>,
}

#[derive(Debug, Clone)]
pub struct PlannedSessionDto {
    pub topic_id: Option<i64>,
    pub topic_name: String,
    pub start: String,
    pub duration_min: i64,
    pub state: String,
}

#[derive(Debug, Clone)]
pub struct PlanProposalDto {
    pub sessions: Vec<PlannedSessionDto>,
    pub total_minutes: i64,
    pub weekly_minutes: i64,
    pub last_date: String,
}

#[derive(Debug, Clone)]
pub struct SessionDto {
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

#[derive(Debug, Clone)]
pub struct ReplanResultDto {
    pub moved: i64,
    pub message: String,
}

#[derive(Debug, Clone)]
pub struct FlashcardDto {
    pub id: i64,
    pub topic_id: i64,
    pub topic_name: String,
    pub subject_id: i64,
    pub question: String,
    pub answer: String,
    pub interval_days: i64,
    pub repetitions: i64,
    pub ease_factor: f64,
    pub next_review: Option<String>,
    pub last_review: Option<String>,
    pub origin: String,
}

#[derive(Debug, Clone)]
pub struct FlashcardProposalDto {
    pub topic_id: i64,
    pub topic_name: String,
    pub question: String,
    pub answer: String,
    pub source: Option<String>,
}

#[derive(Debug, Clone)]
pub struct ReviewResultDto {
    pub flashcard: FlashcardDto,
    pub quality: i64,
    pub mastery: f64,
    pub message: String,
}

#[derive(Debug, Clone)]
pub struct MasteryOverviewDto {
    pub topic_id: i64,
    pub topic_name: String,
    pub mastery: f64,
    pub due_cards: i64,
    pub reviews: i64,
}

#[derive(Debug, Clone)]
pub struct XpConfigDto {
    pub read_section: i64,
    pub task: i64,
    pub quiz_passed: i64,
    pub session: i64,
    pub assessment: i64,
    pub streak_7d: i64,
    pub master_topic: i64,
}

#[derive(Debug, Clone)]
pub struct BadgeDto {
    pub code: String,
    pub title: String,
    pub description: String,
    pub earned: bool,
}

#[derive(Debug, Clone)]
pub struct GamificationSummaryDto {
    pub profile_id: i64,
    pub total_xp: i64,
    pub level: i64,
    pub xp_in_level: i64,
    pub xp_for_next_level: i64,
    pub current_streak: i64,
    pub best_streak: i64,
    pub freeze_enabled: bool,
    pub badges: Vec<BadgeDto>,
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

impl From<domain::Topic> for TopicDto {
    fn from(value: domain::Topic) -> Self {
        Self {
            id: value.id,
            subject_id: value.subject_id,
            parent_id: value.parent_id,
            name: value.name,
            difficulty: value.difficulty,
            mastery: value.mastery,
        }
    }
}

impl From<domain::AvailabilityDay> for AvailabilityDayDto {
    fn from(value: domain::AvailabilityDay) -> Self {
        Self {
            weekday: value.weekday,
            minutes: value.minutes,
        }
    }
}

impl From<domain::PlanSettings> for PlanSettingsDto {
    fn from(value: domain::PlanSettings) -> Self {
        Self {
            subject_id: value.subject_id,
            session_minutes: value.session_minutes,
            start_hour: value.start_hour,
            deadline: value.deadline,
            availability: value.availability.into_iter().map(Into::into).collect(),
        }
    }
}

impl From<domain::PlannedSession> for PlannedSessionDto {
    fn from(value: domain::PlannedSession) -> Self {
        Self {
            topic_id: value.topic_id,
            topic_name: value.topic_name,
            start: value.start,
            duration_min: value.duration_min,
            state: value.state,
        }
    }
}

impl From<domain::PlanProposal> for PlanProposalDto {
    fn from(value: domain::PlanProposal) -> Self {
        Self {
            sessions: value.sessions.into_iter().map(Into::into).collect(),
            total_minutes: value.total_minutes,
            weekly_minutes: value.weekly_minutes,
            last_date: value.last_date,
        }
    }
}

impl From<domain::Session> for SessionDto {
    fn from(value: domain::Session) -> Self {
        Self {
            id: value.id,
            subject_id: value.subject_id,
            topic_id: value.topic_id,
            topic_name: value.topic_name,
            subject_name: value.subject_name,
            subject_color: value.subject_color,
            start: value.start,
            duration_min: value.duration_min,
            state: value.state,
            original_start: value.original_start,
        }
    }
}

impl From<domain::ReplanResult> for ReplanResultDto {
    fn from(value: domain::ReplanResult) -> Self {
        Self {
            moved: value.moved,
            message: value.message,
        }
    }
}

impl From<domain::Flashcard> for FlashcardDto {
    fn from(value: domain::Flashcard) -> Self {
        Self {
            id: value.id,
            topic_id: value.topic_id,
            topic_name: value.topic_name,
            subject_id: value.subject_id,
            question: value.question,
            answer: value.answer,
            interval_days: value.interval_days,
            repetitions: value.repetitions,
            ease_factor: value.ease_factor,
            next_review: value.next_review,
            last_review: value.last_review,
            origin: value.origin,
        }
    }
}

impl From<domain::FlashcardProposal> for FlashcardProposalDto {
    fn from(value: domain::FlashcardProposal) -> Self {
        Self {
            topic_id: value.topic_id,
            topic_name: value.topic_name,
            question: value.question,
            answer: value.answer,
            source: value.source,
        }
    }
}

impl From<domain::ReviewResult> for ReviewResultDto {
    fn from(value: domain::ReviewResult) -> Self {
        Self {
            flashcard: value.flashcard.into(),
            quality: value.quality,
            mastery: value.mastery,
            message: value.message,
        }
    }
}

impl From<domain::MasteryOverview> for MasteryOverviewDto {
    fn from(value: domain::MasteryOverview) -> Self {
        Self {
            topic_id: value.topic_id,
            topic_name: value.topic_name,
            mastery: value.mastery,
            due_cards: value.due_cards,
            reviews: value.reviews,
        }
    }
}

impl From<domain::XpConfig> for XpConfigDto {
    fn from(value: domain::XpConfig) -> Self {
        Self {
            read_section: value.read_section,
            task: value.task,
            quiz_passed: value.quiz_passed,
            session: value.session,
            assessment: value.assessment,
            streak_7d: value.streak_7d,
            master_topic: value.master_topic,
        }
    }
}

impl From<XpConfigDto> for domain::XpConfig {
    fn from(value: XpConfigDto) -> Self {
        Self {
            read_section: value.read_section,
            task: value.task,
            quiz_passed: value.quiz_passed,
            session: value.session,
            assessment: value.assessment,
            streak_7d: value.streak_7d,
            master_topic: value.master_topic,
        }
    }
}

impl From<domain::Badge> for BadgeDto {
    fn from(value: domain::Badge) -> Self {
        Self {
            code: value.code,
            title: value.title,
            description: value.description,
            earned: value.earned,
        }
    }
}

impl From<domain::GamificationSummary> for GamificationSummaryDto {
    fn from(value: domain::GamificationSummary) -> Self {
        Self {
            profile_id: value.profile_id,
            total_xp: value.total_xp,
            level: value.level,
            xp_in_level: value.xp_in_level,
            xp_for_next_level: value.xp_for_next_level,
            current_streak: value.current_streak,
            best_streak: value.best_streak,
            freeze_enabled: value.freeze_enabled,
            badges: value.badges.into_iter().map(Into::into).collect(),
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

pub fn list_topics(subject_id: i64) -> anyhow::Result<Vec<TopicDto>> {
    let topics = db::with_db(|database| database.list_topics(subject_id))?;
    Ok(topics.into_iter().map(TopicDto::from).collect())
}

pub fn create_topic(subject_id: i64, name: String, difficulty: f64) -> anyhow::Result<TopicDto> {
    let topic = db::with_db(|database| database.create_topic(subject_id, &name, difficulty))?;
    Ok(topic.into())
}

pub fn update_topic(id: i64, name: String, difficulty: f64) -> anyhow::Result<TopicDto> {
    let topic = db::with_db(|database| database.update_topic(id, &name, difficulty))?;
    Ok(topic.into())
}

pub fn delete_topic(id: i64) -> anyhow::Result<()> {
    db::with_db(|database| database.delete_topic(id))?;
    Ok(())
}

pub fn get_plan_settings(subject_id: i64) -> anyhow::Result<PlanSettingsDto> {
    let settings = db::with_db(|database| database.get_plan_settings(subject_id))?;
    Ok(settings.into())
}

pub fn save_plan_settings(
    subject_id: i64,
    session_minutes: i64,
    start_hour: i64,
    deadline: String,
    availability: Vec<AvailabilityDayDto>,
) -> anyhow::Result<PlanSettingsDto> {
    let settings = domain::PlanSettings {
        subject_id,
        session_minutes,
        start_hour,
        deadline,
        availability: availability
            .into_iter()
            .map(|day| domain::AvailabilityDay {
                weekday: day.weekday,
                minutes: day.minutes,
            })
            .collect(),
    };
    let saved = db::with_db(|database| database.save_plan_settings(&settings))?;
    Ok(saved.into())
}

pub fn preview_plan(subject_id: i64) -> anyhow::Result<PlanProposalDto> {
    let proposal = db::with_db(|database| crate::planning::preview_plan(database, subject_id))?;
    Ok(proposal.into())
}

pub fn save_plan(subject_id: i64, sessions: Vec<PlannedSessionDto>) -> anyhow::Result<i64> {
    let sessions: Vec<domain::PlannedSession> = sessions
        .into_iter()
        .map(|session| domain::PlannedSession {
            topic_id: session.topic_id,
            topic_name: session.topic_name,
            start: session.start,
            duration_min: session.duration_min,
            state: "pendiente".to_string(),
        })
        .collect();
    let count =
        db::with_db(|database| crate::planning::save_plan(database, subject_id, &sessions))?;
    Ok(count)
}

pub fn list_sessions(
    profile_id: i64,
    subject_id: Option<i64>,
    start: String,
    end: String,
) -> anyhow::Result<Vec<SessionDto>> {
    let sessions =
        db::with_db(|database| database.list_sessions(profile_id, subject_id, &start, &end))?;
    Ok(sessions.into_iter().map(SessionDto::from).collect())
}

pub fn set_session_state(id: i64, state: String) -> anyhow::Result<()> {
    db::with_db(|database| database.set_session_state(id, &state))?;
    Ok(())
}

pub fn replan_subject(subject_id: i64) -> anyhow::Result<ReplanResultDto> {
    let result = db::with_db(|database| crate::planning::replan_now(database, subject_id))?;
    Ok(result.into())
}

pub fn revert_replan(subject_id: i64) -> anyhow::Result<i64> {
    let reverted = db::with_db(|database| crate::planning::revert_replan(database, subject_id))?;
    Ok(reverted)
}

pub fn list_flashcards(subject_id: i64) -> anyhow::Result<Vec<FlashcardDto>> {
    let cards = db::with_db(|database| database.list_flashcards(subject_id))?;
    Ok(cards.into_iter().map(FlashcardDto::from).collect())
}

pub fn create_flashcard(
    topic_id: i64,
    question: String,
    answer: String,
) -> anyhow::Result<FlashcardDto> {
    let card = db::with_db(|database| database.create_flashcard(topic_id, &question, &answer))?;
    Ok(card.into())
}

pub fn update_flashcard(id: i64, question: String, answer: String) -> anyhow::Result<FlashcardDto> {
    let card = db::with_db(|database| database.update_flashcard(id, &question, &answer))?;
    Ok(card.into())
}

pub fn delete_flashcard(id: i64) -> anyhow::Result<()> {
    db::with_db(|database| database.delete_flashcard(id))?;
    Ok(())
}

pub fn list_due_flashcards(subject_id: i64) -> anyhow::Result<Vec<FlashcardDto>> {
    let cards = db::with_db(|database| crate::learning::due_flashcards(database, subject_id))?;
    Ok(cards.into_iter().map(FlashcardDto::from).collect())
}

pub fn review_flashcard(id: i64, quality: i64) -> anyhow::Result<ReviewResultDto> {
    let result = db::with_db(|database| crate::learning::review_now(database, id, quality))?;
    Ok(result.into())
}

pub fn preview_flashcards(subject_id: i64) -> anyhow::Result<Vec<FlashcardProposalDto>> {
    let proposals =
        db::with_db(|database| crate::learning::preview_flashcards(database, subject_id))?;
    Ok(proposals
        .into_iter()
        .map(FlashcardProposalDto::from)
        .collect())
}

pub fn save_flashcards(
    subject_id: i64,
    proposals: Vec<FlashcardProposalDto>,
) -> anyhow::Result<i64> {
    let proposals: Vec<domain::FlashcardProposal> = proposals
        .into_iter()
        .map(|proposal| domain::FlashcardProposal {
            topic_id: proposal.topic_id,
            topic_name: proposal.topic_name,
            question: proposal.question,
            answer: proposal.answer,
            source: proposal.source,
        })
        .collect();
    let count =
        db::with_db(|database| crate::learning::save_flashcards(database, subject_id, &proposals))?;
    Ok(count)
}
pub fn list_mastery(subject_id: i64) -> anyhow::Result<Vec<MasteryOverviewDto>> {
    let overview = db::with_db(|database| crate::learning::mastery_overview(database, subject_id))?;
    Ok(overview.into_iter().map(MasteryOverviewDto::from).collect())
}

pub fn get_xp_config(subject_id: i64) -> anyhow::Result<XpConfigDto> {
    let config = db::with_db(|database| crate::gamification::get_xp_config(database, subject_id))?;
    Ok(config.into())
}

pub fn save_xp_config(subject_id: i64, config: XpConfigDto) -> anyhow::Result<XpConfigDto> {
    let config = domain::XpConfig::from(config);
    let saved =
        db::with_db(|database| crate::gamification::save_xp_config(database, subject_id, &config))?;
    Ok(saved.into())
}

pub fn get_gamification_summary(profile_id: i64) -> anyhow::Result<GamificationSummaryDto> {
    let summary = db::with_db(|database| crate::gamification::summary(database, profile_id))?;
    Ok(summary.into())
}
