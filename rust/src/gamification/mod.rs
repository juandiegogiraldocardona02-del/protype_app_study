//! XP configurable, niveles, rachas e insignias (Etapa E5).

use chrono::{Datelike, NaiveDate};

use crate::db::Database;
use crate::domain::{Badge, GamificationSummary, LevelProgress, Streak, XpConfig};
use crate::error::{CoreError, CoreResult};

const MAX_XP_VALUE: i64 = 10_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct StreakAdvance {
    pub current_days: i64,
    pub best_days: i64,
    pub last_activity_date: NaiveDate,
    pub freeze_used_on: Option<NaiveDate>,
    pub milestone: Option<i64>,
}

pub fn validate_config(config: &XpConfig) -> CoreResult<()> {
    let values = [
        ("leer sección", config.read_section),
        ("tarea", config.task),
        ("cuestionario aprobado", config.quiz_passed),
        ("sesión", config.session),
        ("evaluación", config.assessment),
        ("racha de 7 días", config.streak_7d),
        ("dominar tema", config.master_topic),
    ];
    for (label, value) in values {
        if !(0..=MAX_XP_VALUE).contains(&value) {
            return Err(CoreError::Validation(format!(
                "el XP de {label} debe estar entre 0 y {MAX_XP_VALUE}"
            )));
        }
    }
    Ok(())
}

pub fn get_xp_config(db: &Database, subject_id: i64) -> CoreResult<XpConfig> {
    db.get_xp_config(subject_id)
}

pub fn save_xp_config(
    db: &mut Database,
    subject_id: i64,
    config: &XpConfig,
) -> CoreResult<XpConfig> {
    validate_config(config)?;
    db.save_xp_config(subject_id, config)
}

pub fn level_progress(total_xp: i64) -> LevelProgress {
    let total = total_xp.max(0);
    let mut level = 1i64;
    let mut required = 100i64;
    let mut consumed = 0i64;
    while total >= consumed + required {
        consumed += required;
        level += 1;
        required += 100;
    }
    LevelProgress {
        level,
        total_xp: total,
        xp_in_level: total - consumed,
        xp_for_next_level: required,
    }
}

pub fn advance_streak(
    current_days: i64,
    best_days: i64,
    last_activity_date: Option<NaiveDate>,
    freeze_enabled: bool,
    freeze_used_on: Option<NaiveDate>,
    today: NaiveDate,
) -> StreakAdvance {
    let (current, freeze_used, continued) = match last_activity_date {
        Some(last) if last == today => (current_days.max(0), freeze_used_on, false),
        Some(last) if last + chrono::Days::new(1) == today => {
            (current_days.max(0) + 1, freeze_used_on, true)
        }
        Some(last) if (today - last).num_days() == 2 && freeze_enabled => {
            let freeze_available = freeze_used_on
                .map(|used| (used.year(), used.month()) != (today.year(), today.month()))
                .unwrap_or(true);
            if freeze_available {
                (current_days.max(0) + 1, Some(today), true)
            } else {
                (1, freeze_used_on, false)
            }
        }
        _ => (1, freeze_used_on, false),
    };
    let best = best_days.max(current);
    let milestone = if continued && current > 0 && current % 7 == 0 {
        Some(current)
    } else {
        None
    };
    StreakAdvance {
        current_days: current,
        best_days: best,
        last_activity_date: today,
        freeze_used_on: freeze_used,
        milestone,
    }
}

pub fn summary(db: &Database, profile_id: i64) -> CoreResult<GamificationSummary> {
    let total_xp = db.xp_total(profile_id)?;
    let level = level_progress(total_xp);
    let streak = db.streak(profile_id)?;
    let reviews = db.review_count(profile_id)?;
    let sessions = db.completed_session_count(profile_id)?;
    let mastered = db.mastered_topic_count(profile_id)?;
    let current = effective_streak(&streak, chrono::Local::now().date_naive());

    let badges = vec![
        Badge {
            code: "primer_repaso".to_string(),
            title: "Primer repaso".to_string(),
            description: "Completa tu primer repaso con flashcards.".to_string(),
            earned: reviews >= 1,
        },
        Badge {
            code: "primera_sesion".to_string(),
            title: "Primera sesión".to_string(),
            description: "Completa una sesión de estudio.".to_string(),
            earned: sessions >= 1,
        },
        Badge {
            code: "racha_7".to_string(),
            title: "Racha de 7 días".to_string(),
            description: "Estudia 7 días seguidos.".to_string(),
            earned: streak.best_days >= 7,
        },
        Badge {
            code: "nivel_5".to_string(),
            title: "Nivel 5".to_string(),
            description: "Alcanza el nivel 5.".to_string(),
            earned: level.level >= 5,
        },
        Badge {
            code: "tema_dominado".to_string(),
            title: "Tema dominado".to_string(),
            description: "Alcanza un dominio del 80 % en un tema.".to_string(),
            earned: mastered >= 1,
        },
        Badge {
            code: "diez_repasos".to_string(),
            title: "Constancia".to_string(),
            description: "Completa 10 repasos.".to_string(),
            earned: reviews >= 10,
        },
    ];

    Ok(GamificationSummary {
        profile_id,
        total_xp,
        level: level.level,
        xp_in_level: level.xp_in_level,
        xp_for_next_level: level.xp_for_next_level,
        current_streak: current,
        best_streak: streak.best_days,
        freeze_enabled: streak.freeze_enabled,
        badges,
    })
}

pub fn record_activity_at(
    db: &mut Database,
    profile_id: i64,
    today: NaiveDate,
    streak_xp: i64,
) -> CoreResult<Streak> {
    db.record_activity_at(profile_id, today, streak_xp)
}

pub fn effective_streak(streak: &Streak, today: NaiveDate) -> i64 {
    let Some(last) = streak
        .last_activity_date
        .as_deref()
        .and_then(|value| NaiveDate::parse_from_str(value, "%Y-%m-%d").ok())
    else {
        return 0;
    };
    let gap = (today - last).num_days();
    if gap <= 1 {
        return streak.current_days.max(0);
    }
    if gap == 2 && streak.freeze_enabled {
        let freeze_available = streak
            .freeze_used_on
            .as_deref()
            .and_then(|value| NaiveDate::parse_from_str(value, "%Y-%m-%d").ok())
            .map(|used| (used.year(), used.month()) != (today.year(), today.month()))
            .unwrap_or(true);
        if freeze_available {
            return streak.current_days.max(0);
        }
    }
    0
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Days, Local};

    use crate::domain::defaults::SUBJECT_COLOR;

    #[test]
    fn level_thresholds_grow_progressively() {
        let start = level_progress(0);
        assert_eq!(
            (start.level, start.xp_in_level, start.xp_for_next_level),
            (1, 0, 100)
        );

        let second = level_progress(120);
        assert_eq!(second.level, 2);
        assert_eq!(second.xp_in_level, 20);
        assert_eq!(second.xp_for_next_level, 200);

        let third = level_progress(300);
        assert_eq!(third.level, 3);
        assert_eq!(third.xp_in_level, 0);
    }

    fn database() -> Database {
        let mut db = Database::open_in_memory().expect("abrir bd");
        let profile = db.create_profile("Ana").expect("perfil");
        db.create_subject(profile.id, "Biología", SUBJECT_COLOR)
            .expect("materia");
        db
    }

    fn complete_session(db: &mut Database, topic_id: Option<i64>, minutes: i64) -> i64 {
        db.replace_pending_sessions(
            1,
            &[crate::domain::PlannedSession {
                topic_id,
                topic_name: "La célula".to_string(),
                start: "2026-02-02T08:00:00".to_string(),
                duration_min: minutes,
                state: "pendiente".to_string(),
            }],
        )
        .expect("sesión");
        let id = db
            .sessions_for_subject(1)
            .expect("sesiones")
            .last()
            .expect("sesión")
            .id;
        db.set_session_state(id, "completada").expect("completar");
        id
    }

    #[test]
    fn session_gives_xp_once_and_uses_saved_config() {
        let mut db = database();
        let id = complete_session(&mut db, None, 50);
        assert_eq!(db.xp_total(1).expect("xp"), 15);
        db.set_session_state(id, "completada")
            .expect("completar de nuevo");
        assert_eq!(db.xp_total(1).expect("xp"), 15);

        let mut config = db.get_xp_config(1).expect("config");
        config.session = 25;
        db.save_xp_config(1, &config).expect("guardar config");
        let second = complete_session(&mut db, None, 50);
        assert_ne!(second, id);
        assert_eq!(db.xp_total(1).expect("xp"), 40);
        assert_eq!(db.get_xp_config(1).expect("config").session, 25);
    }

    #[test]
    fn review_records_streak_and_mastery_award() {
        let mut db = database();
        let topic_id = db.create_topic(1, "La célula", 1.0).expect("tema").id;
        complete_session(&mut db, Some(topic_id), 120);
        let card = db
            .create_flashcard(topic_id, "Pregunta", "Respuesta")
            .expect("tarjeta");
        let now = Local::now().naive_local();
        let first = db.review_flashcard_at(card.id, 5, now).expect("repasar");
        assert!((first.mastery - 1.0).abs() < 1e-9);
        assert_eq!(
            db.xp_total(1).expect("xp"),
            165,
            "sesión 15 + dominar tema 150"
        );

        db.review_flashcard_at(card.id, 5, now)
            .expect("repasar de nuevo");
        assert_eq!(db.xp_total(1).expect("xp"), 165);
    }

    #[test]
    fn streak_milestone_awards_xp() {
        let mut db = database();
        let today = Local::now().date_naive();
        let start = today - Days::new(6);
        for day in 0..7 {
            db.record_activity_at(1, start + Days::new(day), 100)
                .expect("racha");
        }
        let streak = db.streak(1).expect("racha");
        assert_eq!(streak.current_days, 7);
        assert_eq!(streak.best_days, 7);
        assert_eq!(db.xp_total(1).expect("xp"), 100);

        let summary = super::summary(&db, 1).expect("resumen");
        assert_eq!(summary.current_streak, 7);
        assert_eq!(summary.level, 2);
        assert!(summary
            .badges
            .iter()
            .any(|badge| badge.code == "racha_7" && badge.earned));
        assert_eq!(effective_streak(&streak, today), 7);
    }

    #[test]
    fn rejects_invalid_xp_config() {
        let config = XpConfig {
            session: -1,
            ..XpConfig::default()
        };
        assert!(matches!(
            validate_config(&config),
            Err(CoreError::Validation(_))
        ));
    }

    #[test]
    fn streak_increments_once_per_day_and_resets() {
        let day = NaiveDate::from_ymd_opt(2026, 2, 2).expect("fecha");
        let first = advance_streak(0, 0, None, true, None, day);
        assert_eq!(first.current_days, 1);

        let same = advance_streak(
            first.current_days,
            first.best_days,
            Some(first.last_activity_date),
            true,
            None,
            day,
        );
        assert_eq!(same.current_days, 1);
        assert!(same.milestone.is_none());

        let next = advance_streak(
            first.current_days,
            first.best_days,
            Some(first.last_activity_date),
            true,
            None,
            day + chrono::Days::new(1),
        );
        assert_eq!(next.current_days, 2);

        let reset = advance_streak(
            next.current_days,
            next.best_days,
            Some(next.last_activity_date),
            true,
            None,
            day + chrono::Days::new(5),
        );
        assert_eq!(reset.current_days, 1);
    }

    #[test]
    fn freeze_covers_one_missed_day_per_month() {
        let start = NaiveDate::from_ymd_opt(2026, 2, 2).expect("fecha");
        let frozen = advance_streak(4, 4, Some(start), true, None, start + chrono::Days::new(2));
        assert_eq!(frozen.current_days, 5);
        assert_eq!(frozen.freeze_used_on, Some(start + chrono::Days::new(2)));

        let no_freeze = advance_streak(
            frozen.current_days,
            frozen.best_days,
            Some(frozen.last_activity_date),
            true,
            frozen.freeze_used_on,
            start + chrono::Days::new(4),
        );
        assert_eq!(no_freeze.current_days, 1);
    }

    #[test]
    fn weekly_milestone_is_reported() {
        let start = NaiveDate::from_ymd_opt(2026, 2, 2).expect("fecha");
        let result = advance_streak(6, 6, Some(start), true, None, start + chrono::Days::new(1));
        assert_eq!(result.current_days, 7);
        assert_eq!(result.milestone, Some(7));
    }
}
