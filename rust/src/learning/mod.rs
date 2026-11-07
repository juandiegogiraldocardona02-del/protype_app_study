//! Repetición espaciada, flashcards y dominio por tema (Etapa E4).

use chrono::{Local, NaiveDateTime};

use crate::db::Database;
use crate::domain::{Flashcard, FlashcardProposal, MasteryOverview, ReviewResult};
use crate::error::{CoreError, CoreResult};

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Schedule {
    pub interval_days: i64,
    pub repetitions: i64,
    pub ease_factor: f64,
}

pub fn schedule(
    repetitions: i64,
    interval_days: i64,
    ease_factor: f64,
    quality: i64,
) -> CoreResult<Schedule> {
    if !(0..=5).contains(&quality) {
        return Err(CoreError::Validation(
            "la calidad del repaso debe estar entre 0 y 5".to_string(),
        ));
    }
    let mut factor = if ease_factor.is_finite() && ease_factor >= 1.3 {
        ease_factor
    } else {
        2.5
    };
    let (interval, repetitions) = if quality < 3 {
        (1, 0)
    } else {
        let next_repetitions = repetitions.max(0) + 1;
        let interval = match repetitions {
            0 => 1,
            1 => 6,
            _ => ((interval_days.max(1) as f64) * factor).round() as i64,
        };
        (interval.max(1), next_repetitions)
    };
    let delta = quality as f64;
    factor = (factor + (0.1 - (5.0 - delta) * (0.08 + (5.0 - delta) * 0.02))).clamp(1.3, 3.0);
    Ok(Schedule {
        interval_days: interval,
        repetitions,
        ease_factor: factor,
    })
}

pub fn preview_flashcards(db: &Database, subject_id: i64) -> CoreResult<Vec<FlashcardProposal>> {
    let topics = db.list_topics(subject_id)?;
    if topics.is_empty() {
        return Err(CoreError::Validation(
            "añade al menos un tema antes de generar tarjetas".to_string(),
        ));
    }
    let snippets = db.document_snippets(subject_id)?;
    let mut proposals = Vec::with_capacity(topics.len());
    for topic in topics {
        let mut matched: Option<(String, String)> = None;
        for (text, label) in &snippets {
            if let Some(sentence) = best_sentence(text, &topic.name) {
                matched = Some((sentence, label.clone()));
                break;
            }
        }
        let (answer, source) = match matched {
            Some((sentence, label)) => (sentence, Some(label)),
            None => (
                format!(
                    "Añade o revisa el contenido sobre «{}» en la biblioteca de la asignatura.",
                    topic.name
                ),
                None,
            ),
        };
        proposals.push(FlashcardProposal {
            topic_id: topic.id,
            topic_name: topic.name.clone(),
            question: format!("¿Qué debes recordar sobre «{}»?", topic.name),
            answer,
            source,
        });
    }
    Ok(proposals)
}

pub fn save_flashcards(
    db: &mut Database,
    subject_id: i64,
    proposals: &[FlashcardProposal],
) -> CoreResult<i64> {
    db.insert_flashcard_proposals(subject_id, proposals)
}

pub fn due_flashcards(db: &Database, subject_id: i64) -> CoreResult<Vec<Flashcard>> {
    db.list_due_flashcards(subject_id, &now_text(Local::now().naive_local()))
}

pub fn review_now(db: &mut Database, id: i64, quality: i64) -> CoreResult<ReviewResult> {
    review_at(db, id, quality, Local::now().naive_local())
}

pub fn review_at(
    db: &mut Database,
    id: i64,
    quality: i64,
    now: NaiveDateTime,
) -> CoreResult<ReviewResult> {
    db.review_flashcard_at(id, quality, now)
}

pub fn mastery_overview(db: &Database, subject_id: i64) -> CoreResult<Vec<MasteryOverview>> {
    db.list_mastery(subject_id, &now_text(Local::now().naive_local()))
}

pub fn now_text(now: NaiveDateTime) -> String {
    now.format("%Y-%m-%dT%H:%M:%S").to_string()
}

fn best_sentence(text: &str, needle: &str) -> Option<String> {
    let needle = needle.trim().to_lowercase();
    if needle.is_empty() {
        return None;
    }
    text.split(['\n', '.', '!', '?', ';'])
        .map(str::trim)
        .filter(|sentence| sentence.chars().count() >= 20)
        .find(|sentence| sentence.to_lowercase().contains(&needle))
        .map(|sentence| truncate_chars(sentence, 280))
}

fn truncate_chars(value: &str, max: usize) -> String {
    if value.chars().count() <= max {
        return value.to_string();
    }
    let mut truncated: String = value.chars().take(max).collect();
    truncated.push('…');
    truncated
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::defaults::SUBJECT_COLOR;

    fn database() -> Database {
        let mut db = Database::open_in_memory().expect("abrir bd");
        let profile = db.create_profile("Ana").expect("perfil");
        db.create_subject(profile.id, "Biología", SUBJECT_COLOR)
            .expect("materia");
        db
    }

    fn add_topic(db: &mut Database) -> i64 {
        db.create_topic(1, "La célula", 1.0).expect("tema").id
    }

    #[test]
    fn sm2_progresses_and_resets() {
        let first = schedule(0, 0, 2.5, 5).expect("programar");
        assert_eq!(first.interval_days, 1);
        assert_eq!(first.repetitions, 1);

        let second = schedule(first.repetitions, first.interval_days, first.ease_factor, 5)
            .expect("programar");
        assert_eq!(second.interval_days, 6);
        assert_eq!(second.repetitions, 2);

        let third = schedule(
            second.repetitions,
            second.interval_days,
            second.ease_factor,
            5,
        )
        .expect("programar");
        assert!(third.interval_days > 6);

        let failed = schedule(third.repetitions, third.interval_days, third.ease_factor, 1)
            .expect("programar");
        assert_eq!(failed.interval_days, 1);
        assert_eq!(failed.repetitions, 0);
        assert!(failed.ease_factor < third.ease_factor);
    }

    #[test]
    fn rejects_out_of_range_quality() {
        assert!(matches!(
            schedule(0, 0, 2.5, 6),
            Err(CoreError::Validation(_))
        ));
    }

    #[test]
    fn creates_updates_and_deletes_flashcards() {
        let mut db = database();
        let topic_id = add_topic(&mut db);
        let card = db
            .create_flashcard(topic_id, "¿Qué es la mitocondria?", "La central energética")
            .expect("crear");
        assert_eq!(card.origin, "manual");
        assert!(card.next_review.is_none());
        assert_eq!(db.list_flashcards(1).expect("listar").len(), 1);

        let updated = db
            .update_flashcard(card.id, "¿Qué hace la mitocondria?", "Produce energía")
            .expect("editar");
        assert_eq!(updated.question, "¿Qué hace la mitocondria?");

        db.delete_flashcard(card.id).expect("eliminar");
        assert!(db.list_flashcards(1).expect("listar").is_empty());
    }

    #[test]
    fn review_updates_schedule_and_mastery() {
        let mut db = database();
        let topic_id = add_topic(&mut db);
        let card = db
            .create_flashcard(topic_id, "Pregunta", "Respuesta")
            .expect("crear");
        let now = NaiveDateTime::parse_from_str("2026-02-02T09:00:00", "%Y-%m-%dT%H:%M:%S")
            .expect("fecha");

        let result = review_at(&mut db, card.id, 5, now).expect("repasar");
        assert_eq!(result.flashcard.repetitions, 1);
        assert_eq!(
            result.flashcard.next_review.as_deref(),
            Some("2026-02-03T09:00:00")
        );
        assert!((result.mastery - 0.6).abs() < 1e-9);
        assert!(db
            .list_due_flashcards(1, "2026-02-02T10:00:00")
            .expect("pendientes")
            .is_empty());

        let earlier = review_at(&mut db, card.id, 2, now).expect("repasar");
        assert_eq!(earlier.flashcard.repetitions, 0);
        assert!(earlier.mastery < result.mastery);
    }

    #[test]
    fn preview_falls_back_when_documents_are_missing() {
        let mut db = database();
        let topic_id = add_topic(&mut db);
        let proposals = preview_flashcards(&db, 1).expect("vista previa");
        assert_eq!(proposals.len(), 1);
        assert_eq!(proposals[0].topic_id, topic_id);
        assert!(proposals[0].source.is_none());

        let saved = save_flashcards(&mut db, 1, &proposals).expect("guardar");
        assert_eq!(saved, 1);
        assert_eq!(db.list_flashcards(1).expect("listar")[0].origin, "auto");
    }

    #[test]
    fn finds_sentences_about_a_topic() {
        let text = "Introducción general.\nLa célula es la unidad básica de la vida. Otra frase.";
        assert_eq!(
            best_sentence(text, "célula").as_deref(),
            Some("La célula es la unidad básica de la vida")
        );
        assert!(best_sentence(text, "mitocondria").is_none());
    }

    #[test]
    fn keeps_mastery_after_completed_time() {
        let mut db = database();
        let topic_id = add_topic(&mut db);
        db.create_flashcard(topic_id, "Pregunta", "Respuesta")
            .expect("crear");
        let session = db
            .replace_pending_sessions(
                1,
                &[crate::domain::PlannedSession {
                    topic_id: Some(topic_id),
                    topic_name: "La célula".to_string(),
                    start: "2026-02-02T08:00:00".to_string(),
                    duration_min: 120,
                    state: "pendiente".to_string(),
                }],
            )
            .expect("sesión");
        assert_eq!(session, 1);
        let session_id = db
            .sessions_for_subject(1)
            .expect("sesiones")
            .first()
            .expect("sesión")
            .id;
        db.set_session_state(session_id, "completada")
            .expect("completar");
        let mastery = db.list_mastery(1, "2026-02-02T10:00:00").expect("dominio");
        assert!((mastery[0].mastery - 0.4).abs() < 1e-9);
    }
}
