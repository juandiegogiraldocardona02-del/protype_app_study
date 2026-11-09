//! Generación y corrección local de evaluaciones (Etapa E8).
//!
//! Las preguntas se construyen exclusivamente con fragmentos de los documentos
//! de la asignatura. La respuesta corta se corrige con una similitud léxica
//! local (solapamiento de términos y trigramas) y un umbral configurable.

use std::collections::{HashMap, HashSet};
use std::hash::{Hash, Hasher};

use crate::db::Database;
use crate::domain::{
    Assessment, AssessmentAnswer, AssessmentProposal, AssessmentQuestion, AssessmentQuestionResult,
    AssessmentResult, Topic,
};
use crate::error::{CoreError, CoreResult};

const DEFAULT_MAX_QUESTIONS: i64 = 10;
const MAX_QUESTIONS: i64 = 30;
const MIN_SENTENCE_CHARS: usize = 40;
const MAX_SENTENCE_CHARS: usize = 500;

const STOPWORDS: &[&str] = &[
    "a", "al", "algo", "algunas", "algunos", "ante", "antes", "como", "con", "contra", "cual",
    "cuando", "de", "del", "desde", "donde", "dos", "el", "ella", "ellas", "ellos", "en", "entre",
    "era", "es", "esa", "esas", "ese", "eso", "esos", "esta", "estas", "este", "esto", "estos",
    "fue", "ha", "han", "hasta", "hay", "la", "las", "le", "les", "lo", "los", "mas", "me", "mi",
    "mis", "mucho", "muy", "no", "nos", "o", "otra", "otras", "otro", "otros", "para", "pero",
    "por", "porque", "que", "se", "ser", "si", "sin", "sobre", "son", "su", "sus", "te", "tiene",
    "todo", "todos", "tu", "tus", "un", "una", "unas", "uno", "unos", "y", "ya",
];

#[derive(Debug, Clone)]
struct Term {
    norm: String,
    display: String,
}

#[derive(Debug, Clone)]
struct Sentence {
    text: String,
    source: String,
    topic_id: Option<i64>,
    topic_name: Option<String>,
}

pub fn generate_assessment(
    db: &Database,
    subject_id: i64,
    max_questions: i64,
) -> CoreResult<AssessmentProposal> {
    db.get_subject(subject_id)?;
    let max_questions = if max_questions <= 0 {
        DEFAULT_MAX_QUESTIONS
    } else {
        max_questions.min(MAX_QUESTIONS)
    };

    let snippets = db.document_snippets(subject_id)?;
    if snippets.is_empty() {
        return Err(CoreError::Validation(
            "No hay documentos con texto en esta asignatura. Importa una fuente para generar preguntas."
                .into(),
        ));
    }
    let topics = db.list_topics(subject_id)?;
    let mut sentences = Vec::new();
    let mut seen_sentences = HashSet::new();
    for (text, source) in &snippets {
        for sentence in split_sentences(text) {
            let key = normalize(&sentence);
            if seen_sentences.insert(key) {
                let (topic_id, topic_name) = topic_for(&sentence, &topics);
                sentences.push(Sentence {
                    text: sentence,
                    source: source.clone(),
                    topic_id,
                    topic_name,
                });
            }
        }
    }
    if sentences.is_empty() {
        return Err(CoreError::Validation(
            "Los documentos no contienen frases suficientes para generar preguntas.".into(),
        ));
    }

    let terms = key_terms(&sentences);
    if terms.len() < 2 {
        return Err(CoreError::Validation(
            "No se encontraron conceptos suficientes en los documentos.".into(),
        ));
    }

    let mut questions = Vec::new();
    let mut seen_prompts = HashSet::new();
    for sentence in &sentences {
        if (questions.len() as i64) >= max_questions {
            break;
        }
        let sentence_terms = terms_in_sentence(&sentence.text, &terms);
        if let Some(term) = sentence_terms.first() {
            push_question(
                &mut questions,
                &mut seen_prompts,
                build_multiple_choice(sentence, term, &terms),
            );
        }
        if (questions.len() as i64) >= max_questions {
            break;
        }
        if let Some(term) = sentence_terms.first() {
            push_question(
                &mut questions,
                &mut seen_prompts,
                build_true_false(sentence, term, &terms, true),
            );
            if (questions.len() as i64) >= max_questions {
                break;
            }
            push_question(
                &mut questions,
                &mut seen_prompts,
                build_true_false(sentence, term, &terms, false),
            );
        }
        if (questions.len() as i64) >= max_questions {
            break;
        }
        push_question(
            &mut questions,
            &mut seen_prompts,
            build_short_answer(sentence),
        );
    }

    if (questions.len() as i64) < max_questions {
        for sentence in &sentences {
            if (questions.len() as i64) >= max_questions {
                break;
            }
            for term in terms_in_sentence(&sentence.text, &terms).iter().skip(1) {
                if (questions.len() as i64) >= max_questions {
                    break;
                }
                push_question(
                    &mut questions,
                    &mut seen_prompts,
                    build_multiple_choice(sentence, term, &terms),
                );
            }
        }
    }

    for (index, question) in questions.iter_mut().enumerate() {
        question.id = index as i64 + 1;
    }
    let message = if questions.len() < 8 {
        format!(
            "Solo se pudieron generar {} preguntas con los documentos actuales.",
            questions.len()
        )
    } else {
        format!(
            "Se generaron {} preguntas desde los documentos.",
            questions.len()
        )
    };
    Ok(AssessmentProposal { questions, message })
}

pub fn grade_assessment(
    db: &mut Database,
    subject_id: i64,
    questions: &[AssessmentQuestion],
    answers: &[AssessmentAnswer],
    threshold: f64,
) -> CoreResult<AssessmentResult> {
    db.get_subject(subject_id)?;
    if questions.is_empty() {
        return Err(CoreError::Validation(
            "No hay preguntas para corregir.".into(),
        ));
    }
    if !threshold.is_finite() || !(0.0..=1.0).contains(&threshold) {
        return Err(CoreError::Validation(
            "el umbral debe estar entre 0 y 1".into(),
        ));
    }
    let answer_map: HashMap<i64, &str> = answers
        .iter()
        .map(|answer| (answer.question_id, answer.answer.trim()))
        .collect();

    let mut details = Vec::new();
    let mut correct_count = 0_i64;
    let mut topic_counts: HashMap<i64, (i64, i64)> = HashMap::new();
    for question in questions {
        let answer = answer_map.get(&question.id).copied().unwrap_or("");
        let (correct, similarity) = match question.kind.as_str() {
            "opcion_multiple" | "verdadero_falso" => {
                let correct = normalize(answer) == normalize(&question.correct_answer);
                (correct, if correct { 1.0 } else { 0.0 })
            }
            "respuesta_corta" => {
                let similarity = short_answer_similarity(answer, &question.correct_answer);
                (similarity >= threshold, similarity)
            }
            other => {
                return Err(CoreError::Validation(format!(
                    "tipo de pregunta no soportado: {other}"
                )))
            }
        };
        if correct {
            correct_count += 1;
        }
        if let Some(topic_id) = question.topic_id {
            let entry = topic_counts.entry(topic_id).or_insert((0, 0));
            entry.1 += 1;
            if correct {
                entry.0 += 1;
            }
        }
        let feedback = match (question.kind.as_str(), correct) {
            ("respuesta_corta", true) => {
                format!("Correcto (similitud {:.0}%).", similarity * 100.0)
            }
            ("respuesta_corta", false) => format!(
                "Similitud {:.0}% (umbral {:.0}%). Respuesta esperada: «{}».",
                similarity * 100.0,
                threshold * 100.0,
                question.correct_answer
            ),
            (_, true) => "Correcto.".to_string(),
            (_, false) => format!("Respuesta correcta: «{}».", question.correct_answer),
        };
        details.push(AssessmentQuestionResult {
            question_id: question.id,
            correct,
            similarity,
            expected: question.correct_answer.clone(),
            feedback,
            source: question.source.clone(),
        });
    }

    let total = questions.len() as i64;
    let score = correct_count as f64 / total as f64;
    let passed = score >= threshold;
    let mut topic_scores: Vec<(i64, i64, i64)> = topic_counts
        .into_iter()
        .map(|(topic_id, (correct, total))| (topic_id, correct, total))
        .collect();
    topic_scores.sort_by_key(|(topic_id, _, _)| *topic_id);
    let assessment = db.record_assessment(crate::db::NewAssessment {
        subject_id,
        kind: "cuestionario",
        score,
        correct: correct_count,
        total,
        threshold,
        topic_scores: &topic_scores,
    })?;
    let message = if passed {
        format!(
            "Cuestionario aprobado: {:.0}% ({}/{}) con umbral {:.0}%.",
            score * 100.0,
            correct_count,
            total,
            threshold * 100.0
        )
    } else {
        format!(
            "Cuestionario no aprobado: {:.0}% ({}/{}) con umbral {:.0}%.",
            score * 100.0,
            correct_count,
            total,
            threshold * 100.0
        )
    };
    Ok(AssessmentResult {
        assessment_id: assessment.id,
        score,
        correct: correct_count,
        total,
        passed,
        message,
        details,
    })
}

pub fn list_assessments(db: &Database, subject_id: i64) -> CoreResult<Vec<Assessment>> {
    db.list_assessments(subject_id)
}

pub fn short_answer_similarity(answer: &str, expected: &str) -> f64 {
    let answer_tokens = content_tokens(answer);
    let expected_tokens = content_tokens(expected);
    if answer_tokens.is_empty() || expected_tokens.is_empty() {
        return 0.0;
    }
    let answer_set: HashSet<&str> = answer_tokens.iter().map(String::as_str).collect();
    let expected_set: HashSet<&str> = expected_tokens.iter().map(String::as_str).collect();
    let intersection = answer_set.intersection(&expected_set).count() as f64;
    let recall = intersection / expected_set.len() as f64;
    let precision = intersection / answer_set.len() as f64;
    let trigram = trigram_similarity(answer, expected);
    (0.55 * recall + 0.25 * precision + 0.20 * trigram).clamp(0.0, 1.0)
}

fn push_question(
    questions: &mut Vec<AssessmentQuestion>,
    seen_prompts: &mut HashSet<String>,
    question: Option<AssessmentQuestion>,
) {
    let Some(question) = question else {
        return;
    };
    if seen_prompts.insert(normalize(&question.prompt)) {
        questions.push(question);
    }
}

fn build_multiple_choice(
    sentence: &Sentence,
    term: &Term,
    all_terms: &[Term],
) -> Option<AssessmentQuestion> {
    let prompt_text = sentence.text.replacen(&term.display, "_____", 1);
    if prompt_text == sentence.text {
        return None;
    }
    let mut options = vec![term.display.clone()];
    for candidate in all_terms {
        if candidate.norm != term.norm
            && !options
                .iter()
                .any(|value| normalize(value) == candidate.norm)
        {
            options.push(candidate.display.clone());
        }
        if options.len() == 4 {
            break;
        }
    }
    if options.len() < 4 {
        return None;
    }
    let prompt = format!("Completa la frase: «{prompt_text}»");
    let shift = stable_hash(&prompt) as usize % options.len();
    options.rotate_left(shift);
    Some(AssessmentQuestion {
        id: 0,
        kind: "opcion_multiple".to_string(),
        prompt,
        options,
        correct_answer: term.display.clone(),
        explanation: format!("Texto original: «{}»", sentence.text),
        source: sentence.source.clone(),
        topic_id: sentence.topic_id,
        topic_name: sentence.topic_name.clone(),
    })
}

fn build_true_false(
    sentence: &Sentence,
    term: &Term,
    all_terms: &[Term],
    truth: bool,
) -> Option<AssessmentQuestion> {
    let (statement, correct_answer, explanation) = if truth {
        (
            sentence.text.clone(),
            "Verdadero".to_string(),
            format!("La afirmación es verdadera: «{}»", sentence.text),
        )
    } else {
        let replacement = all_terms
            .iter()
            .find(|candidate| candidate.norm != term.norm)?;
        let statement = sentence
            .text
            .replacen(&term.display, &replacement.display, 1);
        if statement == sentence.text {
            return None;
        }
        (
            statement,
            "Falso".to_string(),
            format!("La afirmación correcta es: «{}»", sentence.text),
        )
    };
    Some(AssessmentQuestion {
        id: 0,
        kind: "verdadero_falso".to_string(),
        prompt: format!("Indica si es verdadera o falsa: «{statement}»"),
        options: vec!["Verdadero".to_string(), "Falso".to_string()],
        correct_answer,
        explanation,
        source: sentence.source.clone(),
        topic_id: sentence.topic_id,
        topic_name: sentence.topic_name.clone(),
    })
}

fn build_short_answer(sentence: &Sentence) -> Option<AssessmentQuestion> {
    let (term, _) = definition_term(&sentence.text)?;
    Some(AssessmentQuestion {
        id: 0,
        kind: "respuesta_corta".to_string(),
        prompt: format!("Define o explica: «{term}»"),
        options: Vec::new(),
        correct_answer: sentence.text.clone(),
        explanation: format!("Respuesta tomada de: «{}»", sentence.text),
        source: sentence.source.clone(),
        topic_id: sentence.topic_id,
        topic_name: sentence.topic_name.clone(),
    })
}

fn definition_term(text: &str) -> Option<(String, usize)> {
    for marker in [
        " se define como ",
        " consiste en ",
        " significa ",
        " es ",
        " son ",
    ] {
        let Some(position) = text.find(marker) else {
            continue;
        };
        let subject = text[..position].trim();
        let subject = subject
            .trim_start_matches(|character: char| {
                matches!(character, '¿' | '¡' | '"' | '\'' | '(' | '[' | '-' | '•')
            })
            .trim();
        let subject = strip_articles(subject);
        let length = subject.chars().count();
        if (3..=80).contains(&length) && !subject.split_whitespace().all(is_stopword) {
            return Some((subject.to_string(), position));
        }
    }
    None
}

fn strip_articles(text: &str) -> &str {
    for article in [
        "la ", "el ", "los ", "las ", "un ", "una ", "unos ", "unas ",
    ] {
        if let Some(rest) = text.strip_prefix(article) {
            return rest.trim();
        }
    }
    text.trim()
}

fn key_terms(sentences: &[Sentence]) -> Vec<Term> {
    let mut counts: HashMap<String, (String, usize)> = HashMap::new();
    for sentence in sentences {
        for token in tokenize(&sentence.text) {
            let norm = normalize(&token);
            if !is_term(&norm) {
                continue;
            }
            let entry = counts.entry(norm).or_insert((token.clone(), 0));
            entry.1 += 1;
        }
    }
    let mut terms: Vec<(String, String, usize)> = counts
        .into_iter()
        .map(|(norm, (display, count))| (norm, display, count))
        .collect();
    terms.sort_by(|left, right| {
        right
            .2
            .cmp(&left.2)
            .then_with(|| right.0.chars().count().cmp(&left.0.chars().count()))
            .then_with(|| left.0.cmp(&right.0))
    });
    terms
        .into_iter()
        .take(200)
        .map(|(norm, display, _)| Term { norm, display })
        .collect()
}

fn terms_in_sentence(text: &str, all_terms: &[Term]) -> Vec<Term> {
    let by_norm: HashMap<&str, &Term> = all_terms
        .iter()
        .map(|term| (term.norm.as_str(), term))
        .collect();
    let mut seen = HashSet::new();
    let mut result = Vec::new();
    for token in tokenize(text) {
        let norm = normalize(&token);
        if let Some(term) = by_norm.get(norm.as_str()) {
            if seen.insert(term.norm.clone()) {
                result.push((*term).clone());
            }
        }
    }
    result
}

fn topic_for(sentence: &str, topics: &[Topic]) -> (Option<i64>, Option<String>) {
    let normalized = normalize(sentence);
    let mut best: Option<(&Topic, usize)> = None;
    for topic in topics {
        let name = normalize(&topic.name);
        if name.is_empty() {
            continue;
        }
        let score = if normalized.contains(&name) {
            name.chars().count() + 100
        } else {
            name.split_whitespace()
                .filter(|word| word.chars().count() >= 4 && !is_stopword(word))
                .filter(|word| normalized.contains(*word))
                .count()
        };
        if score > 0 && best.map(|(_, value)| score > value).unwrap_or(true) {
            best = Some((topic, score));
        }
    }
    best.map(|(topic, _)| (Some(topic.id), Some(topic.name.clone())))
        .unwrap_or((None, None))
}

fn split_sentences(text: &str) -> Vec<String> {
    let mut sentences = Vec::new();
    for part in text.split(['.', '!', '?', ';', '\n']) {
        let sentence = part
            .trim()
            .trim_matches(|character: char| {
                matches!(character, '"' | '\'' | '«' | '»' | '(' | ')' | '[' | ']')
            })
            .trim();
        let length = sentence.chars().count();
        if (MIN_SENTENCE_CHARS..=MAX_SENTENCE_CHARS).contains(&length) {
            sentences.push(sentence.to_string());
        }
    }
    sentences
}

fn tokenize(text: &str) -> Vec<String> {
    let mut tokens = Vec::new();
    let mut current = String::new();
    for character in text.chars() {
        if character.is_alphanumeric() {
            current.push(character);
        } else if !current.is_empty() {
            tokens.push(std::mem::take(&mut current));
        }
    }
    if !current.is_empty() {
        tokens.push(current);
    }
    tokens
}

fn content_tokens(text: &str) -> Vec<String> {
    tokenize(text)
        .into_iter()
        .map(|token| normalize(&token))
        .filter(|token| token.chars().count() >= 2 && !is_stopword(token))
        .collect()
}

fn normalize(text: &str) -> String {
    text.chars()
        .flat_map(|character| character.to_lowercase())
        .map(fold_accent)
        .filter(|character| character.is_alphanumeric() || character.is_whitespace())
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn fold_accent(character: char) -> char {
    match character {
        'á' | 'à' | 'ä' | 'â' => 'a',
        'é' | 'è' | 'ë' | 'ê' => 'e',
        'í' | 'ì' | 'ï' | 'î' => 'i',
        'ó' | 'ò' | 'ö' | 'ô' => 'o',
        'ú' | 'ù' | 'ü' | 'û' => 'u',
        'ñ' => 'n',
        other => other,
    }
}

fn is_term(norm: &str) -> bool {
    norm.chars().count() >= 4
        && !is_stopword(norm)
        && norm.chars().any(|character| character.is_alphabetic())
        && !norm.chars().all(|character| character.is_numeric())
}

fn is_stopword(word: &str) -> bool {
    STOPWORDS.contains(&word)
}

fn stable_hash(text: &str) -> u64 {
    let mut hasher = std::collections::hash_map::DefaultHasher::new();
    text.hash(&mut hasher);
    hasher.finish()
}

fn trigram_similarity(left: &str, right: &str) -> f64 {
    let left = trigrams(left);
    let right = trigrams(right);
    if left.is_empty() || right.is_empty() {
        return 0.0;
    }
    let intersection = left.intersection(&right).count() as f64;
    let union = left.union(&right).count() as f64;
    intersection / union
}

fn trigrams(text: &str) -> HashSet<String> {
    let normalized = normalize(text).replace(' ', "");
    let characters: Vec<char> = normalized.chars().collect();
    if characters.len() < 3 {
        return if characters.is_empty() {
            HashSet::new()
        } else {
            HashSet::from([normalized])
        };
    }
    characters
        .windows(3)
        .map(|window| window.iter().collect())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::NewDocument;
    use crate::domain::AvailabilityDay;
    use std::fs;
    use std::path::PathBuf;

    fn database() -> (Database, i64) {
        let mut db = Database::open_in_memory().expect("base");
        let profile = db.create_profile("Ana").expect("perfil");
        let subject = db
            .create_subject(profile.id, "Biología", "#059669")
            .expect("asignatura");
        db.create_topic(subject.id, "La célula", 1.2).expect("tema");
        let text = [
            "La célula es la unidad estructural y funcional de todos los seres vivos.",
            "La membrana celular regula el intercambio de sustancias con el exterior.",
            "El núcleo contiene el material genético y coordina las funciones celulares.",
            "Las mitocondrias producen energía mediante la respiración celular.",
            "Los ribosomas sintetizan proteínas siguiendo las instrucciones del ARN.",
            "El citoplasma es el medio interno donde ocurren muchas reacciones químicas.",
            "Los cloroplastos realizan la fotosíntesis en las células vegetales.",
            "La pared celular aporta rigidez y protección a las células vegetales.",
            "El aparato de Golgi modifica y empaqueta proteínas para su transporte.",
            "Los lisosomas degradan sustancias y participan en la digestión celular.",
            "El retículo endoplasmático participa en la síntesis y el transporte de proteínas.",
            "Las vacuolas almacenan agua y otras sustancias en el interior de la célula.",
        ]
        .join(" ");
        let path = std::env::temp_dir().join(format!(
            "study_planner_assessment_{}.txt",
            std::process::id()
        ));
        fs::write(&path, &text).expect("texto");
        db.insert_document(NewDocument {
            subject_id: subject.id,
            name: "apunte.txt".to_string(),
            local_path: path.to_string_lossy().to_string(),
            kind: "txt".to_string(),
            hash: "hash".to_string(),
            version: 1,
            extraction_status: "ok".to_string(),
            extraction_message: None,
            chunks: vec![text],
        })
        .expect("documento");
        (db, subject.id)
    }

    #[test]
    fn generates_at_least_eight_questions_from_documents() {
        let (db, subject_id) = database();
        let proposal = generate_assessment(&db, subject_id, 10).expect("generar");
        assert!(proposal.questions.len() >= 8);
        assert!(proposal.questions.len() <= 10);
        assert!(proposal
            .questions
            .iter()
            .all(|question| question.source.contains("apunte.txt")));
        assert!(proposal
            .questions
            .iter()
            .any(|question| { question.kind == "opcion_multiple" && question.options.len() == 4 }));
        assert!(proposal
            .questions
            .iter()
            .any(|question| question.kind == "verdadero_falso"));
        assert!(proposal
            .questions
            .iter()
            .any(|question| question.kind == "respuesta_corta"));
    }

    #[test]
    fn grades_answers_and_records_assessment() {
        let (mut db, subject_id) = database();
        let proposal = generate_assessment(&db, subject_id, 10).expect("generar");
        let answers: Vec<AssessmentAnswer> = proposal
            .questions
            .iter()
            .map(|question| AssessmentAnswer {
                question_id: question.id,
                answer: question.correct_answer.clone(),
            })
            .collect();
        let result = grade_assessment(&mut db, subject_id, &proposal.questions, &answers, 0.6)
            .expect("corregir");
        assert_eq!(result.correct, result.total);
        assert!((result.score - 1.0).abs() < 1e-9);
        assert!(result.passed);
        assert!(result.assessment_id > 0);
        assert_eq!(db.list_assessments(subject_id).expect("historial").len(), 1);
        assert!(db.xp_total(1).expect("xp") >= 30);
        let mastery = db
            .list_mastery(subject_id, "2026-01-01T00:00:00")
            .expect("dominio");
        assert!(mastery
            .iter()
            .any(|item| item.topic_name == "La célula" && item.mastery > 0.0));
    }

    #[test]
    fn short_answer_similarity_accepts_related_text_and_rejects_noise() {
        let expected = "La célula es la unidad estructural y funcional de los seres vivos.";
        let related = "unidad estructural y funcional de los seres vivos";
        let noise = "el clima cambia durante el invierno";
        assert!(short_answer_similarity(related, expected) >= 0.6);
        assert!(short_answer_similarity(noise, expected) < 0.2);
    }

    #[test]
    fn rejects_subject_without_documents() {
        let mut db = Database::open_in_memory().expect("base");
        let profile = db.create_profile("Ana").expect("perfil");
        let subject = db
            .create_subject(profile.id, "Vacía", "#000000")
            .expect("asignatura");
        assert!(generate_assessment(&db, subject.id, 10).is_err());
    }

    #[test]
    fn validates_threshold_and_empty_questions() {
        let (mut db, subject_id) = database();
        let proposal = generate_assessment(&db, subject_id, 3).expect("generar");
        let answers = proposal
            .questions
            .iter()
            .map(|question| AssessmentAnswer {
                question_id: question.id,
                answer: String::new(),
            })
            .collect::<Vec<_>>();
        assert!(grade_assessment(&mut db, subject_id, &proposal.questions, &answers, 1.5).is_err());
        assert!(grade_assessment(&mut db, subject_id, &[], &[], 0.6).is_err());
    }

    #[allow(dead_code)]
    fn _keep_path_type_used(_: PathBuf, _: AvailabilityDay) {}
}
