//! Planificación académica automática y replanificación (Etapa E3).

use std::collections::BTreeMap;
use std::collections::HashMap;

use chrono::{Datelike, Duration, Local, NaiveDate, NaiveDateTime, NaiveTime, Timelike};

use crate::db::Database;
use crate::domain::{
    GuidedPlanProposal, PlanProposal, PlanSettings, PlannedSession, ReplanResult, Session, Topic,
};
use crate::error::{CoreError, CoreResult};

const MAX_SCAN_DAYS: i64 = 730;

#[derive(Debug, Clone)]
struct SessionRequest {
    topic_id: Option<i64>,
    topic_name: String,
    duration_min: i64,
}

struct GuideStep {
    title: &'static str,
    minutes: i64,
}

struct IntensityPreset {
    level: &'static str,
    label: &'static str,
    description: &'static str,
    multiplier: f64,
    steps: &'static [usize],
    topics: usize,
}

const GUIDE_STEPS: &[GuideStep] = &[
    GuideStep {
        title: "Definir objetivo",
        minutes: 3,
    },
    GuideStep {
        title: "Preparar material",
        minutes: 5,
    },
    GuideStep {
        title: "Entrar en estado",
        minutes: 7,
    },
    GuideStep {
        title: "Macrolectura",
        minutes: 8,
    },
    GuideStep {
        title: "Formular preguntas",
        minutes: 5,
    },
    GuideStep {
        title: "Lectura activa",
        minutes: 25,
    },
    GuideStep {
        title: "Pausa activa",
        minutes: 2,
    },
    GuideStep {
        title: "Escucha activa",
        minutes: 15,
    },
    GuideStep {
        title: "Mapa mental",
        minutes: 10,
    },
    GuideStep {
        title: "Recitación",
        minutes: 10,
    },
    GuideStep {
        title: "Autoevaluación",
        minutes: 10,
    },
    GuideStep {
        title: "Enseñar a otra persona",
        minutes: 5,
    },
    GuideStep {
        title: "Repaso espaciado",
        minutes: 5,
    },
    GuideStep {
        title: "Descanso y sueño",
        minutes: 480,
    },
    GuideStep {
        title: "Revisión semanal",
        minutes: 20,
    },
];

const PRESET_MEDIO: IntensityPreset = IntensityPreset {
    level: "medio",
    label: "Medio",
    description: "Repaso ligero: objetivo, preparación, macrolectura y repaso espaciado.",
    multiplier: 0.6,
    steps: &[0, 1, 3, 5, 10, 12],
    topics: 1,
};

const PRESET_INTERMEDIO: IntensityPreset = IntensityPreset {
    level: "intermedio",
    label: "Intermedio · recomendado",
    description: "Plan recomendado: lectura activa, mapa mental, recitación y autoevaluación.",
    multiplier: 1.0,
    steps: &[0, 1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 14],
    topics: 2,
};

const PRESET_INTENSO: IntensityPreset = IntensityPreset {
    level: "intenso",
    label: "Intenso",
    description: "Cobertura completa: añade escucha activa, enseñanza y repaso semanal.",
    multiplier: 1.3,
    steps: &[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14],
    topics: 3,
};

pub fn preview_plan(db: &Database, subject_id: i64) -> CoreResult<PlanProposal> {
    let topics = db.list_topics(subject_id)?;
    let settings = db.get_plan_settings(subject_id)?;
    generate_plan(&topics, &settings, Local::now().date_naive())
}

pub fn preview_guided_plan(
    db: &Database,
    subject_id: i64,
    level: &str,
    include_today: bool,
) -> CoreResult<GuidedPlanProposal> {
    let topics = db.list_topics(subject_id)?;
    let settings = db.get_plan_settings(subject_id)?;
    let now = Local::now().naive_local();
    generate_guided_plan(&topics, &settings, now.date(), now, level, include_today)
}

pub fn save_plan(
    db: &mut Database,
    subject_id: i64,
    sessions: &[PlannedSession],
) -> CoreResult<i64> {
    db.replace_pending_sessions(subject_id, sessions)
}

pub fn replan_now(db: &mut Database, subject_id: i64) -> CoreResult<ReplanResult> {
    replan_at(db, subject_id, Local::now().naive_local())
}

pub fn replan_at(
    db: &mut Database,
    subject_id: i64,
    now: NaiveDateTime,
) -> CoreResult<ReplanResult> {
    let settings = db.get_plan_settings(subject_id)?;
    let sessions = db.sessions_for_subject(subject_id)?;
    let pending: Vec<Session> = sessions
        .iter()
        .filter(|session| session.state != "completada")
        .cloned()
        .collect();
    if pending.is_empty() {
        return Ok(ReplanResult {
            moved: 0,
            message: "No hay sesiones pendientes por replanificar.".to_string(),
        });
    }
    let completed: Vec<Session> = sessions
        .iter()
        .filter(|session| session.state == "completada")
        .cloned()
        .collect();

    let moves = reschedule_pending(&pending, &completed, &settings, now)?;
    let moved = db.apply_replan(&moves)?;
    Ok(ReplanResult {
        moved,
        message: format!("Se recolocaron {moved} sesiones pendientes. Puedes deshacer el cambio."),
    })
}

pub fn revert_replan(db: &mut Database, subject_id: i64) -> CoreResult<i64> {
    db.revert_replan(subject_id)
}

pub fn generate_plan(
    topics: &[Topic],
    settings: &PlanSettings,
    start_date: NaiveDate,
) -> CoreResult<PlanProposal> {
    validate_settings(settings)?;
    if topics.is_empty() {
        return Err(CoreError::Validation(
            "añade al menos un tema antes de generar el plan".to_string(),
        ));
    }

    let mut requests = Vec::new();
    for topic in topics {
        for _ in 0..sessions_for_topic(topic.difficulty) {
            requests.push(SessionRequest {
                topic_id: Some(topic.id),
                topic_name: topic.name.clone(),
                duration_min: settings.session_minutes,
            });
        }
    }
    let now = start_date
        .and_hms_opt(0, 0, 0)
        .ok_or_else(|| CoreError::Validation("hora inicial inválida".to_string()))?;
    schedule_requests(&requests, settings, start_date, now, false, false)
}

pub fn generate_guided_plan(
    topics: &[Topic],
    settings: &PlanSettings,
    start_date: NaiveDate,
    now: NaiveDateTime,
    level: &str,
    include_today: bool,
) -> CoreResult<GuidedPlanProposal> {
    validate_base_settings(settings)?;
    if topics.is_empty() {
        return Err(CoreError::Validation(
            "añade al menos un tema antes de generar el plan".to_string(),
        ));
    }
    let preset = intensity_preset(level)?;
    let mut ordered = topics.to_vec();
    ordered.sort_by(|left, right| {
        right
            .difficulty
            .total_cmp(&left.difficulty)
            .then_with(|| left.mastery.total_cmp(&right.mastery))
            .then_with(|| left.id.cmp(&right.id))
    });
    let selected = &ordered[..preset.topics.min(ordered.len())];
    let mut requests = Vec::new();
    for topic in selected {
        for index in preset.steps {
            let step = &GUIDE_STEPS[*index];
            let duration = ((step.minutes as f64 * preset.multiplier).round() as i64).max(5);
            requests.push(SessionRequest {
                topic_id: Some(topic.id),
                topic_name: format!("{} · {}", step.title, topic.name),
                duration_min: duration,
            });
        }
    }
    let proposal = schedule_requests(&requests, settings, start_date, now, include_today, true)?;
    Ok(GuidedPlanProposal {
        level: preset.level.to_string(),
        label: preset.label.to_string(),
        description: preset.description.to_string(),
        topics_count: selected.len() as i64,
        steps_count: preset.steps.len() as i64,
        total_minutes: proposal.total_minutes,
        weekly_minutes: proposal.weekly_minutes,
        last_date: proposal.last_date,
        sessions: proposal.sessions,
    })
}

fn schedule_requests(
    requests: &[SessionRequest],
    settings: &PlanSettings,
    start_date: NaiveDate,
    now: NaiveDateTime,
    include_today: bool,
    use_current_slot: bool,
) -> CoreResult<PlanProposal> {
    validate_base_settings(settings)?;
    if requests.is_empty() {
        return Err(CoreError::Validation(
            "el plan debe contener al menos una sesión".to_string(),
        ));
    }
    let deadline = parse_deadline(settings)?;
    if deadline < start_date {
        return Err(CoreError::Validation(
            "la fecha límite ya pasó; elige una fecha futura".to_string(),
        ));
    }

    let max_duration = requests
        .iter()
        .map(|request| request.duration_min)
        .max()
        .unwrap_or(settings.session_minutes);
    let mut capacity: HashMap<i64, i64> = settings
        .availability
        .iter()
        .map(|day| (day.weekday, day.minutes))
        .collect();
    if include_today {
        let weekday = start_date.weekday().number_from_monday() as i64;
        let forced = max_duration.max(120);
        capacity
            .entry(weekday)
            .and_modify(|minutes| *minutes = (*minutes).max(forced))
            .or_insert(forced);
    }
    if !capacity.values().any(|minutes| *minutes >= max_duration) {
        return Err(CoreError::Validation(
            "ningún día tiene capacidad para una sesión completa".to_string(),
        ));
    }

    let mut sessions = Vec::with_capacity(requests.len());
    let mut index = 0usize;
    let mut day = start_date;
    let mut scanned = 0i64;

    while index < requests.len() {
        if day > deadline || scanned >= MAX_SCAN_DAYS {
            return Err(CoreError::Validation(
                "el plan no cabe antes de la fecha límite; amplía la disponibilidad \
                 o reduce la duración de las sesiones"
                    .to_string(),
            ));
        }
        let weekday = day.weekday().number_from_monday() as i64;
        if let Some(minutes) = capacity.get(&weekday) {
            let mut used = 0i64;
            let mut slot_start = if use_current_slot && day == now.date() {
                first_slot(day, settings.start_hour, now)?
            } else {
                at_hour(day, settings.start_hour)?
            };
            while index < requests.len() {
                let request = &requests[index];
                if used + request.duration_min > *minutes {
                    break;
                }
                let end = slot_start + Duration::minutes(request.duration_min);
                if end.date() != day {
                    break;
                }
                sessions.push(PlannedSession {
                    topic_id: request.topic_id,
                    topic_name: request.topic_name.clone(),
                    start: format_start(slot_start),
                    duration_min: request.duration_min,
                    state: "pendiente".to_string(),
                });
                used += request.duration_min;
                slot_start = end;
                index += 1;
            }
        }
        day = day.succ_opt().ok_or_else(|| {
            CoreError::Validation("no se pudo avanzar la fecha del plan".to_string())
        })?;
        scanned += 1;
    }

    let last_date = sessions
        .last()
        .map(|session| session.start[..10].to_string())
        .unwrap_or_else(|| start_date.to_string());
    let total_minutes = sessions
        .iter()
        .map(|session| session.duration_min)
        .sum::<i64>();

    Ok(PlanProposal {
        total_minutes,
        weekly_minutes: settings.weekly_minutes(),
        last_date,
        sessions,
    })
}

fn intensity_preset(level: &str) -> CoreResult<&'static IntensityPreset> {
    match level.trim().to_lowercase().as_str() {
        "medio" => Ok(&PRESET_MEDIO),
        "intermedio" => Ok(&PRESET_INTERMEDIO),
        "intenso" => Ok(&PRESET_INTENSO),
        _ => Err(CoreError::Validation(
            "intensidad no válida; usa medio, intermedio o intenso".to_string(),
        )),
    }
}

pub fn reschedule_pending(
    pending: &[Session],
    completed: &[Session],
    settings: &PlanSettings,
    now: NaiveDateTime,
) -> CoreResult<Vec<(i64, String)>> {
    validate_settings(settings)?;
    if pending.is_empty() {
        return Ok(Vec::new());
    }
    let deadline = parse_deadline(settings)?;
    if deadline < now.date() {
        return Err(CoreError::Validation(
            "la fecha límite ya pasó; actualiza la configuración del plan".to_string(),
        ));
    }

    let capacity: HashMap<i64, i64> = settings
        .availability
        .iter()
        .map(|day| (day.weekday, day.minutes))
        .collect();
    let mut reserved: BTreeMap<NaiveDate, i64> = BTreeMap::new();
    for session in completed {
        if let Ok(start) = NaiveDateTime::parse_from_str(&session.start, "%Y-%m-%dT%H:%M:%S") {
            *reserved.entry(start.date()).or_insert(0) += session.duration_min;
        }
    }

    let max_duration = pending
        .iter()
        .map(|session| session.duration_min)
        .max()
        .unwrap_or(0);
    if !capacity.values().any(|minutes| *minutes >= max_duration) {
        return Err(CoreError::Validation(
            "ningún día tiene capacidad suficiente para una sesión pendiente".to_string(),
        ));
    }

    let mut moves = Vec::with_capacity(pending.len());
    let mut index = 0usize;
    let mut day = now.date();
    let mut scanned = 0i64;

    while index < pending.len() {
        if day > deadline || scanned >= MAX_SCAN_DAYS {
            return Err(CoreError::Validation(
                "no hay disponibilidad suficiente antes de la fecha límite para \
                 recolocar las sesiones pendientes"
                    .to_string(),
            ));
        }
        let weekday = day.weekday().number_from_monday() as i64;
        if let Some(minutes) = capacity.get(&weekday) {
            let used = reserved.get(&day).copied().unwrap_or(0);
            let mut available = *minutes - used;
            let mut slot_start = first_slot(day, settings.start_hour, now)?;
            while index < pending.len() {
                let duration = pending[index].duration_min;
                if available < duration {
                    break;
                }
                let end = slot_start + Duration::minutes(duration);
                if end.date() != day {
                    break;
                }
                moves.push((pending[index].id, format_start(slot_start)));
                available -= duration;
                slot_start = end;
                index += 1;
            }
        }
        day = day.succ_opt().ok_or_else(|| {
            CoreError::Validation("no se pudo avanzar la fecha de replanificación".to_string())
        })?;
        scanned += 1;
    }

    Ok(moves)
}

fn validate_settings(settings: &PlanSettings) -> CoreResult<()> {
    validate_base_settings(settings)?;
    if !settings
        .availability
        .iter()
        .any(|day| day.minutes >= settings.session_minutes)
    {
        return Err(CoreError::Validation(
            "ningún día tiene capacidad para una sesión completa".to_string(),
        ));
    }
    Ok(())
}

fn validate_base_settings(settings: &PlanSettings) -> CoreResult<()> {
    if !(15..=240).contains(&settings.session_minutes) {
        return Err(CoreError::Validation(
            "la duración de sesión debe estar entre 15 y 240 minutos".to_string(),
        ));
    }
    if !(0..=23).contains(&settings.start_hour) {
        return Err(CoreError::Validation(
            "la hora de inicio debe estar entre 0 y 23".to_string(),
        ));
    }
    if settings.availability.is_empty() {
        return Err(CoreError::Validation(
            "configura al menos un día de disponibilidad".to_string(),
        ));
    }
    Ok(())
}

fn parse_deadline(settings: &PlanSettings) -> CoreResult<NaiveDate> {
    NaiveDate::parse_from_str(&settings.deadline, "%Y-%m-%d").map_err(|_| {
        CoreError::Validation("la fecha límite no es válida; usa el formato AAAA-MM-DD".to_string())
    })
}

fn sessions_for_topic(difficulty: f64) -> usize {
    let rounded = difficulty.round() as i64;
    rounded.clamp(1, 3) as usize
}

fn at_hour(day: NaiveDate, hour: i64) -> CoreResult<NaiveDateTime> {
    let time = NaiveTime::from_hms_opt(hour as u32, 0, 0)
        .ok_or_else(|| CoreError::Validation("hora de inicio inválida".to_string()))?;
    Ok(day.and_time(time))
}

fn first_slot(day: NaiveDate, start_hour: i64, now: NaiveDateTime) -> CoreResult<NaiveDateTime> {
    let base = at_hour(day, start_hour)?;
    if day != now.date() {
        return Ok(base);
    }
    let seconds = now.time().num_seconds_from_midnight() as i64;
    let rounded = ((seconds + 299) / 300) * 300;
    let earliest = now.date().and_hms_opt(0, 0, 0).ok_or_else(|| {
        CoreError::Validation("no se pudo calcular la hora de replanificación".to_string())
    })? + Duration::seconds(rounded);
    Ok(if earliest > base { earliest } else { base })
}

fn format_start(value: NaiveDateTime) -> String {
    value.format("%Y-%m-%dT%H:%M:%S").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::{AvailabilityDay, PlannedSession};

    fn topic(id: i64, name: &str, difficulty: f64) -> Topic {
        Topic {
            id,
            subject_id: 1,
            parent_id: None,
            name: name.to_string(),
            difficulty,
            mastery: 0.0,
        }
    }

    fn settings(duration: i64) -> PlanSettings {
        PlanSettings {
            subject_id: 1,
            session_minutes: duration,
            start_hour: 8,
            deadline: "2026-02-28".to_string(),
            availability: (1..=5)
                .map(|weekday| AvailabilityDay {
                    weekday,
                    minutes: 120,
                })
                .collect(),
        }
    }

    fn date(year: i32, month: u32, day: u32) -> NaiveDate {
        NaiveDate::from_ymd_opt(year, month, day).expect("fecha válida")
    }

    #[test]
    fn generates_sessions_within_availability() {
        let topics = vec![
            topic(1, "Tema 1", 1.0),
            topic(2, "Tema 2", 1.0),
            topic(3, "Tema 3", 1.0),
            topic(4, "Tema 4", 1.0),
            topic(5, "Tema 5", 1.0),
        ];
        let proposal = generate_plan(&topics, &settings(60), date(2026, 2, 2)).expect("plan");

        assert_eq!(proposal.sessions.len(), 5);
        assert_eq!(proposal.total_minutes, 300);
        assert_eq!(proposal.weekly_minutes, 600);
        assert_eq!(proposal.last_date, "2026-02-04");
        assert_eq!(proposal.sessions[0].start, "2026-02-02T08:00:00");
        assert_eq!(proposal.sessions[1].start, "2026-02-02T09:00:00");
        assert_eq!(proposal.sessions[2].start, "2026-02-03T08:00:00");
    }

    #[test]
    fn never_exceeds_daily_availability() {
        let topics: Vec<Topic> = (1..=20)
            .map(|id| topic(id, &format!("Tema {id}"), 1.0))
            .collect();
        let proposal = generate_plan(&topics, &settings(50), date(2026, 2, 2)).expect("plan");

        assert_eq!(proposal.sessions.len(), 20);
        let mut per_day = std::collections::BTreeMap::new();
        for session in &proposal.sessions {
            let day = &session.start[..10];
            *per_day.entry(day.to_string()).or_insert(0) += session.duration_min;
        }
        assert!(per_day.values().all(|minutes| *minutes <= 120));
        assert!(proposal.last_date.as_str() <= "2026-02-28");
    }

    #[test]
    fn rejects_plan_that_does_not_fit_deadline() {
        let topics: Vec<Topic> = (1..=20)
            .map(|id| topic(id, &format!("Tema {id}"), 1.0))
            .collect();
        let too_short = PlanSettings {
            deadline: "2026-02-02".to_string(),
            ..settings(50)
        };
        let error = generate_plan(&topics, &too_short, date(2026, 2, 2)).expect_err("no cabe");
        assert!(matches!(error, CoreError::Validation(_)));
    }

    #[test]
    fn rejects_plan_without_topics() {
        let error = generate_plan(&[], &settings(50), date(2026, 2, 2)).expect_err("sin temas");
        assert!(matches!(error, CoreError::Validation(_)));
    }

    #[test]
    fn guided_plans_scale_by_intensity() {
        let topics = vec![
            topic(1, "Tema 1", 3.0),
            topic(2, "Tema 2", 2.0),
            topic(3, "Tema 3", 1.0),
        ];
        let now = date(2026, 2, 2).and_hms_opt(8, 0, 0).expect("hora");
        let medio = generate_guided_plan(
            &topics,
            &settings(50),
            date(2026, 2, 2),
            now,
            "medio",
            false,
        )
        .expect("medio");
        let intermedio = generate_guided_plan(
            &topics,
            &settings(50),
            date(2026, 2, 2),
            now,
            "Intermedio",
            false,
        )
        .expect("intermedio");
        let intenso = generate_guided_plan(
            &topics,
            &settings(50),
            date(2026, 2, 2),
            now,
            "intenso",
            false,
        )
        .expect("intenso");

        assert_eq!(medio.topics_count, 1);
        assert_eq!(medio.steps_count, 6);
        assert_eq!(medio.sessions.len(), 6);
        assert_eq!(intermedio.topics_count, 2);
        assert_eq!(intermedio.steps_count, 12);
        assert_eq!(intermedio.sessions.len(), 24);
        assert_eq!(intenso.topics_count, 3);
        assert_eq!(intenso.steps_count, 14);
        assert_eq!(intenso.sessions.len(), 42);
        assert!(medio.total_minutes < intermedio.total_minutes);
        assert!(intermedio.total_minutes < intenso.total_minutes);
        assert!(intenso.last_date.as_str() <= "2026-02-28");
    }

    #[test]
    fn guided_plan_can_include_today_outside_availability() {
        let topics = vec![topic(1, "Tema 1", 3.0)];
        let monday = PlanSettings {
            deadline: "2026-03-31".to_string(),
            availability: vec![AvailabilityDay {
                weekday: 1,
                minutes: 120,
            }],
            ..settings(50)
        };
        let start = date(2026, 2, 3);
        let now = start.and_hms_opt(10, 0, 0).expect("hora");
        let without_today =
            generate_guided_plan(&topics, &monday, start, now, "medio", false).expect("sin hoy");
        let with_today =
            generate_guided_plan(&topics, &monday, start, now, "medio", true).expect("con hoy");

        assert_eq!(without_today.sessions[0].start, "2026-02-09T08:00:00");
        assert_eq!(with_today.sessions[0].start, "2026-02-03T10:00:00");
        assert_eq!(&with_today.sessions[0].start[..10], "2026-02-03");
    }

    #[test]
    fn reschedules_pending_after_completed_minutes() {
        let now = date(2026, 2, 2).and_hms_opt(10, 0, 0).expect("hora");
        let pending = vec![
            session(1, "2026-01-05T08:00:00", 50, "pendiente"),
            session(2, "2026-01-05T09:00:00", 50, "pendiente"),
        ];
        let completed = vec![session(3, "2026-02-02T08:00:00", 50, "completada")];

        let moves = reschedule_pending(&pending, &completed, &settings(50), now).expect("replan");

        assert_eq!(moves.len(), 2);
        assert_eq!(moves[0].1, "2026-02-02T10:00:00");
        assert_eq!(moves[1].1, "2026-02-03T08:00:00");
    }

    #[test]
    fn rejects_replan_after_deadline() {
        let now = date(2026, 3, 1).and_hms_opt(10, 0, 0).expect("hora");
        let pending = vec![session(1, "2026-01-05T08:00:00", 50, "pendiente")];
        let error = reschedule_pending(&pending, &[], &settings(50), now).expect_err("vencido");
        assert!(matches!(error, CoreError::Validation(_)));
    }

    #[test]
    fn replan_and_revert_round_trip() {
        let mut db = Database::open_in_memory().expect("bd");
        let profile = db.create_profile("Ana").expect("perfil");
        let subject = db
            .create_subject(profile.id, "Física", "#0891B2")
            .expect("materia");
        let mut config = settings(50);
        config.subject_id = subject.id;
        config.availability = (1..=7)
            .map(|weekday| AvailabilityDay {
                weekday,
                minutes: 120,
            })
            .collect();
        db.save_plan_settings(&config).expect("guardar config");

        let proposed = vec![
            PlannedSession {
                topic_id: None,
                topic_name: "Repaso".to_string(),
                start: "2026-01-05T08:00:00".to_string(),
                duration_min: 50,
                state: "pendiente".to_string(),
            },
            PlannedSession {
                topic_id: None,
                topic_name: "Repaso".to_string(),
                start: "2026-01-05T09:00:00".to_string(),
                duration_min: 50,
                state: "pendiente".to_string(),
            },
        ];
        db.replace_pending_sessions(subject.id, &proposed)
            .expect("guardar plan");

        let now = date(2026, 2, 2).and_hms_opt(10, 0, 0).expect("hora");
        let result = replan_at(&mut db, subject.id, now).expect("replanificar");
        assert_eq!(result.moved, 2);

        let replanned = db.sessions_for_subject(subject.id).expect("listar");
        assert!(replanned.iter().all(|item| item.state == "replanificada"));
        assert!(replanned.iter().all(|item| item.original_start.is_some()));

        let reverted = revert_replan(&mut db, subject.id).expect("revertir");
        assert_eq!(reverted, 2);
        let restored = db.sessions_for_subject(subject.id).expect("listar");
        assert!(restored.iter().all(|item| item.state == "pendiente"));
        assert!(restored.iter().all(|item| item.original_start.is_none()));
        assert_eq!(restored[0].start, "2026-01-05T08:00:00");
    }

    fn session(id: i64, start: &str, duration: i64, state: &str) -> Session {
        Session {
            id,
            subject_id: 1,
            topic_id: None,
            topic_name: None,
            subject_name: "Física".to_string(),
            subject_color: "#0891B2".to_string(),
            start: start.to_string(),
            duration_min: duration,
            state: state.to_string(),
            original_start: None,
            studied_seconds: 0,
            started_at: None,
        }
    }
}
