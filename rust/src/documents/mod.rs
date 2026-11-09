//! Importación, extracción de texto, OCR opcional y versionado de fuentes
//! (Etapa E2).

use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::Command;

use sha2::{Digest, Sha256};

use crate::db::{Database, NewDocument};
use crate::domain::{Document, ImportOutcome};
use crate::error::{CoreError, CoreResult};

const CHUNK_CHARS: usize = 3000;
const MAX_TEXT_CHARS: usize = 8_000_000;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DocumentKind {
    Pdf,
    Text,
    Image,
    Audio,
}

impl DocumentKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Pdf => "pdf",
            Self::Text => "txt",
            Self::Image => "imagen",
            Self::Audio => "audio",
        }
    }

    fn from_path(path: &Path) -> CoreResult<Self> {
        let extension = path
            .extension()
            .and_then(|value| value.to_str())
            .map(|value| value.to_ascii_lowercase())
            .ok_or_else(|| {
                CoreError::Validation("el archivo no tiene una extensión válida".into())
            })?;
        match extension.as_str() {
            "pdf" => Ok(Self::Pdf),
            "txt" => Ok(Self::Text),
            "png" | "jpg" | "jpeg" | "bmp" | "tif" | "tiff" | "webp" => Ok(Self::Image),
            "mp3" | "wav" | "m4a" | "aac" | "ogg" | "flac" => Ok(Self::Audio),
            other => Err(CoreError::Validation(format!(
                "formato «{other}» no soportado (usa PDF, TXT, imágenes o audio)"
            ))),
        }
    }
}

struct Extraction {
    text: String,
    status: String,
    message: Option<String>,
    ocr_used: bool,
}

pub fn ocr_binary() -> String {
    std::env::var("TESSERACT_PATH")
        .ok()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "tesseract".to_string())
}

pub fn ocr_available() -> bool {
    Command::new(ocr_binary())
        .arg("--version")
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

pub fn whisper_binary() -> String {
    std::env::var("STUDY_PLANNER_WHISPER_BIN")
        .ok()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "whisper-cli".to_string())
}

pub fn whisper_available() -> bool {
    Command::new(whisper_binary())
        .arg("--help")
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

pub fn whisper_model() -> Option<PathBuf> {
    if let Ok(value) = std::env::var("STUDY_PLANNER_WHISPER_MODEL") {
        let path = PathBuf::from(value.trim());
        if path.is_file() {
            return Some(path);
        }
    }
    let directory = crate::db::models_directory()?;
    let mut candidates: Vec<PathBuf> = std::fs::read_dir(directory)
        .ok()?
        .filter_map(|entry| entry.ok())
        .map(|entry| entry.path())
        .filter(|path| {
            path.is_file()
                && path
                    .extension()
                    .and_then(|value| value.to_str())
                    .map(|value| value.eq_ignore_ascii_case("bin"))
                    .unwrap_or(false)
        })
        .filter(|path| {
            path.file_name()
                .and_then(|value| value.to_str())
                .map(|name| {
                    name.to_ascii_lowercase().contains("whisper") || name.starts_with("ggml-")
                })
                .unwrap_or(false)
        })
        .collect();
    candidates.sort();
    candidates.into_iter().next()
}

pub fn audio_available() -> bool {
    whisper_available() && whisper_model().is_some()
}

pub fn import_document(
    db: &mut Database,
    subject_id: i64,
    path: &str,
) -> CoreResult<ImportOutcome> {
    db.get_subject(subject_id)?;

    let path = PathBuf::from(path);
    if !path.is_file() {
        return Err(CoreError::Validation(format!(
            "la ruta no existe o no es un archivo: {}",
            path.display()
        )));
    }
    let kind = DocumentKind::from_path(&path)?;
    let hash = hash_file(&path)?;

    if let Some(existing) = db.find_document_by_hash(subject_id, &hash)? {
        let message = format!(
            "El documento ya estaba importado como «{}» (versión {}).",
            existing.name, existing.version
        );
        return Ok(ImportOutcome {
            document: existing,
            duplicate: true,
            ocr_used: false,
            message,
        });
    }

    let name = path
        .file_name()
        .and_then(|value| value.to_str())
        .ok_or_else(|| CoreError::Validation("nombre de archivo inválido".into()))?
        .to_string();
    let version = db.next_document_version(subject_id, &name)?;

    let extraction = extract(&path, kind);

    let text = truncate_text(extraction.text);
    let (status, message) = if text.trim().is_empty() {
        (
            if extraction.status == "ok" {
                "vacio".to_string()
            } else {
                extraction.status
            },
            extraction
                .message
                .or_else(|| Some("No se encontró texto en el documento.".to_string())),
        )
    } else {
        ("ok".to_string(), extraction.message)
    };

    let chunks = chunk_text(&text);
    let document = db.insert_document(NewDocument {
        subject_id,
        name,
        local_path: path.to_string_lossy().into_owned(),
        kind: kind.as_str().to_string(),
        hash,
        version,
        extraction_status: status.clone(),
        extraction_message: message.clone(),
        chunks,
    })?;

    let message = if document.text_chars > 0 {
        format!(
            "Importado con {} caracteres extraídos (versión {}).",
            document.text_chars, document.version
        )
    } else {
        message.unwrap_or_else(|| "Documento importado sin texto extraído.".to_string())
    };

    Ok(ImportOutcome {
        document,
        duplicate: false,
        ocr_used: extraction.ocr_used,
        message,
    })
}

pub fn list_documents(db: &Database, subject_id: i64) -> CoreResult<Vec<Document>> {
    db.list_documents(subject_id)
}

pub fn delete_document(db: &mut Database, id: i64) -> CoreResult<()> {
    db.delete_document(id)
}

fn extract(path: &Path, kind: DocumentKind) -> Extraction {
    match kind {
        DocumentKind::Text => match std::fs::read(path) {
            Ok(bytes) => Extraction {
                text: String::from_utf8_lossy(&bytes).into_owned(),
                status: "ok".to_string(),
                message: None,
                ocr_used: false,
            },
            Err(error) => Extraction {
                text: String::new(),
                status: "error".to_string(),
                message: Some(format!("No se pudo leer el TXT: {error}")),
                ocr_used: false,
            },
        },
        DocumentKind::Pdf => match pdf_extract::extract_text(path) {
            Ok(text) => Extraction {
                text,
                status: "ok".to_string(),
                message: None,
                ocr_used: false,
            },
            Err(error) => Extraction {
                text: String::new(),
                status: "error".to_string(),
                message: Some(format!("No se pudo extraer texto del PDF: {error}")),
                ocr_used: false,
            },
        },
        DocumentKind::Audio => transcribe_audio(path),
        DocumentKind::Image => {
            if !ocr_available() {
                return Extraction {
                    text: String::new(),
                    status: "ocr_no_disponible".to_string(),
                    message: Some(
                        "Tesseract no está instalado; la imagen se importó sin texto. \
                         Instala Tesseract o define TESSERACT_PATH para activar el OCR."
                            .to_string(),
                    ),
                    ocr_used: false,
                };
            }
            match run_ocr(path) {
                Ok(text) => Extraction {
                    text,
                    status: "ok".to_string(),
                    message: None,
                    ocr_used: true,
                },
                Err(error) => Extraction {
                    text: String::new(),
                    status: "error".to_string(),
                    message: Some(format!("OCR falló: {error}")),
                    ocr_used: false,
                },
            }
        }
    }
}

fn ffmpeg_binary() -> String {
    std::env::var("STUDY_PLANNER_FFMPEG")
        .ok()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "ffmpeg".to_string())
}

fn ffmpeg_available() -> bool {
    Command::new(ffmpeg_binary())
        .arg("-version")
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}

fn transcribe_audio(path: &Path) -> Extraction {
    if !whisper_available() {
        return Extraction {
            text: String::new(),
            status: "whisper_no_disponible".to_string(),
            message: Some(
                "whisper.cpp no está instalado; el audio se importó sin transcripción. \
                 Define STUDY_PLANNER_WHISPER_BIN para activarla."
                    .to_string(),
            ),
            ocr_used: false,
        };
    }
    let Some(model) = whisper_model() else {
        return Extraction {
            text: String::new(),
            status: "whisper_sin_modelo".to_string(),
            message: Some(
                "No se encontró un modelo de whisper.cpp (ggml-*.bin). \
                 Define STUDY_PLANNER_WHISPER_MODEL o colócalo en la carpeta models."
                    .to_string(),
            ),
            ocr_used: false,
        };
    };

    let mut temporary = Vec::new();
    let wav_path = if path
        .extension()
        .and_then(|value| value.to_str())
        .map(|value| value.eq_ignore_ascii_case("wav"))
        .unwrap_or(false)
    {
        path.to_path_buf()
    } else {
        if !ffmpeg_available() {
            return Extraction {
                text: String::new(),
                status: "audio_sin_ffmpeg".to_string(),
                message: Some(
                    "El audio requiere ffmpeg para convertirse a WAV; se importó sin \
                     transcripción. Instala ffmpeg o define STUDY_PLANNER_FFMPEG."
                        .to_string(),
                ),
                ocr_used: false,
            };
        }
        let wav = temporary_path("wav");
        temporary.push(wav.clone());
        if let Err(error) = convert_to_wav(path, &wav) {
            cleanup_paths(&temporary);
            return Extraction {
                text: String::new(),
                status: "error".to_string(),
                message: Some(format!("No se pudo convertir el audio con ffmpeg: {error}")),
                ocr_used: false,
            };
        }
        wav
    };

    let output_base = temporary_path("whisper");
    temporary.push(output_base.with_extension("txt"));
    let result = run_whisper(&model, &wav_path, &output_base);
    let extraction = match result {
        Ok(text) => Extraction {
            text,
            status: "ok".to_string(),
            message: None,
            ocr_used: false,
        },
        Err(error) => Extraction {
            text: String::new(),
            status: "error".to_string(),
            message: Some(format!("La transcripción falló: {error}")),
            ocr_used: false,
        },
    };
    cleanup_paths(&temporary);
    extraction
}

fn convert_to_wav(input: &Path, output: &Path) -> CoreResult<()> {
    let result = Command::new(ffmpeg_binary())
        .arg("-y")
        .arg("-i")
        .arg(input)
        .arg("-ar")
        .arg("16000")
        .arg("-ac")
        .arg("1")
        .arg("-c:a")
        .arg("pcm_s16le")
        .arg(output)
        .output()?;
    if !result.status.success() {
        return Err(CoreError::Unexpected(
            String::from_utf8_lossy(&result.stderr).trim().to_string(),
        ));
    }
    Ok(())
}

fn run_whisper(model: &Path, wav: &Path, output_base: &Path) -> CoreResult<String> {
    let language = std::env::var("STUDY_PLANNER_WHISPER_LANG")
        .ok()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "es".to_string());
    let result = Command::new(whisper_binary())
        .arg("-m")
        .arg(model)
        .arg("-f")
        .arg(wav)
        .arg("-l")
        .arg(language.trim())
        .arg("-otxt")
        .arg("-of")
        .arg(output_base)
        .output()?;
    if !result.status.success() {
        return Err(CoreError::Unexpected(
            String::from_utf8_lossy(&result.stderr).trim().to_string(),
        ));
    }
    let text_path = output_base.with_extension("txt");
    let text = std::fs::read_to_string(&text_path)?;
    Ok(text)
}

fn temporary_path(extension: &str) -> PathBuf {
    let nanos = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_nanos())
        .unwrap_or_default();
    std::env::temp_dir().join(format!(
        "study_planner_audio_{}_{}.{}",
        std::process::id(),
        nanos,
        extension
    ))
}

fn cleanup_paths(paths: &[PathBuf]) {
    for path in paths {
        let _ = std::fs::remove_file(path);
    }
}

fn run_ocr(path: &Path) -> CoreResult<String> {
    let mut command = Command::new(ocr_binary());
    command.arg(path).arg("stdout");
    if let Ok(language) = std::env::var("TESSERACT_LANG") {
        if !language.trim().is_empty() {
            command.arg("-l").arg(language.trim());
        }
    }
    let output = command.output()?;
    if !output.status.success() {
        return Err(CoreError::Unexpected(format!(
            "Tesseract terminó con error: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        )));
    }
    Ok(String::from_utf8_lossy(&output.stdout).into_owned())
}

fn hash_file(path: &Path) -> CoreResult<String> {
    let mut file = std::fs::File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = [0u8; 64 * 1024];
    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        hasher.update(&buffer[..read]);
    }
    Ok(hex::encode(hasher.finalize()))
}

fn truncate_text(text: String) -> String {
    if text.chars().count() <= MAX_TEXT_CHARS {
        return text;
    }
    text.chars().take(MAX_TEXT_CHARS).collect()
}

fn chunk_text(text: &str) -> Vec<String> {
    let mut chunks = Vec::new();
    let mut current = String::new();
    let mut current_chars = 0usize;

    for word in text.split_whitespace() {
        let word_chars = word.chars().count();
        if !current.is_empty() && current_chars + 1 + word_chars > CHUNK_CHARS {
            chunks.push(std::mem::take(&mut current));
            current_chars = 0;
        }
        if !current.is_empty() {
            current.push(' ');
            current_chars += 1;
        }
        current.push_str(word);
        current_chars += word_chars;
    }
    if !current.is_empty() {
        chunks.push(current);
    }
    chunks
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::Database;

    fn temp_dir(tag: &str) -> PathBuf {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .expect("reloj del sistema")
            .as_nanos();
        let dir = std::env::temp_dir().join(format!(
            "study_planner_docs_{tag}_{}_{nanos}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).expect("crear dir temporal");
        dir
    }

    fn setup(tag: &str) -> (Database, i64, PathBuf) {
        let mut db = Database::open_in_memory().expect("abrir bd");
        let profile = db.create_profile("Ana").expect("perfil");
        let subject = db
            .create_subject(profile.id, "Biología", "#059669")
            .expect("materia");
        let dir = temp_dir(tag);
        (db, subject.id, dir)
    }

    fn import(db: &mut Database, subject_id: i64, path: &Path) -> ImportOutcome {
        import_document(db, subject_id, path.to_str().expect("ruta utf8"))
            .expect("importar documento")
    }

    #[test]
    fn imports_txt_document_with_text() {
        let (mut db, subject_id, dir) = setup("txt");
        let path = dir.join("apuntes.txt");
        std::fs::write(
            &path,
            "La célula es la unidad básica de la vida.\n\nMitocondrias.",
        )
        .expect("escribir txt");

        let outcome = import(&mut db, subject_id, &path);

        assert!(!outcome.duplicate);
        assert_eq!(outcome.document.kind, "txt");
        assert_eq!(outcome.document.version, 1);
        assert_eq!(outcome.document.extraction_status, "ok");
        assert!(outcome.document.text_chars > 0);
        assert_eq!(list_documents(&db, subject_id).expect("listar").len(), 1);

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn identical_content_is_not_duplicated() {
        let (mut db, subject_id, dir) = setup("dup");
        let path = dir.join("resumen.txt");
        std::fs::write(&path, "Contenido estable").expect("escribir txt");

        let first = import(&mut db, subject_id, &path);
        let second = import(&mut db, subject_id, &path);

        assert!(!first.duplicate);
        assert!(second.duplicate);
        assert_eq!(first.document.id, second.document.id);
        assert_eq!(list_documents(&db, subject_id).expect("listar").len(), 1);

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn same_name_with_new_content_increments_version() {
        let (mut db, subject_id, dir) = setup("ver");
        let path = dir.join("temario.txt");
        std::fs::write(&path, "Versión uno del temario").expect("escribir v1");
        let first = import(&mut db, subject_id, &path);

        std::fs::write(&path, "Versión dos del temario con cambios").expect("escribir v2");
        let second = import(&mut db, subject_id, &path);

        assert_eq!(first.document.version, 1);
        assert_eq!(second.document.version, 2);
        assert_ne!(first.document.id, second.document.id);
        assert_eq!(list_documents(&db, subject_id).expect("listar").len(), 2);

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn rejects_unsupported_extension() {
        let (mut db, subject_id, dir) = setup("unsupported");
        let path = dir.join("tabla.xlsx");
        std::fs::write(&path, "datos").expect("escribir archivo");

        let error = import_document(&mut db, subject_id, path.to_str().expect("ruta"))
            .expect_err("debe fallar");
        assert!(matches!(error, CoreError::Validation(_)));

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn rejects_missing_file() {
        let (mut db, subject_id, dir) = setup("missing");
        let path = dir.join("no_existe.txt");

        let error = import_document(&mut db, subject_id, path.to_str().expect("ruta"))
            .expect_err("debe fallar");
        assert!(matches!(error, CoreError::Validation(_)));

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn rejects_unknown_subject() {
        let (_db, _subject_id, dir) = setup("nosubject");
        let path = dir.join("apuntes.txt");
        std::fs::write(&path, "texto").expect("escribir");
        drop(_db);

        let mut db = Database::open_in_memory().expect("abrir bd");
        let error =
            import_document(&mut db, 999, path.to_str().expect("ruta")).expect_err("debe fallar");
        assert!(matches!(error, CoreError::NotFound(_)));

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn deletes_document() {
        let (mut db, subject_id, dir) = setup("delete");
        let path = dir.join("borrar.txt");
        std::fs::write(&path, "contenido").expect("escribir");
        let outcome = import(&mut db, subject_id, &path);

        delete_document(&mut db, outcome.document.id).expect("eliminar");
        assert!(list_documents(&db, subject_id).expect("listar").is_empty());

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn image_is_imported_even_without_ocr() {
        let (mut db, subject_id, dir) = setup("img");
        let path = dir.join("escaneo.png");
        std::fs::write(&path, [0x89, 0x50, 0x4E, 0x47]).expect("escribir png");

        let outcome = import(&mut db, subject_id, &path);

        assert_eq!(outcome.document.kind, "imagen");
        assert_eq!(outcome.document.text_chars, 0);
        if !ocr_available() {
            assert_eq!(outcome.document.extraction_status, "ocr_no_disponible");
            assert!(!outcome.ocr_used);
        }

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn audio_is_imported_even_without_whisper() {
        let (mut db, subject_id, dir) = setup("audio");
        let path = dir.join("clase.mp3");
        std::fs::write(&path, b"ID3audio").expect("escribir audio");

        let outcome = import(&mut db, subject_id, &path);

        assert_eq!(outcome.document.kind, "audio");
        assert_eq!(outcome.document.text_chars, 0);
        assert!(!outcome.ocr_used);
        if !audio_available() {
            assert!(matches!(
                outcome.document.extraction_status.as_str(),
                "whisper_no_disponible" | "whisper_sin_modelo" | "audio_sin_ffmpeg"
            ));
        }

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn chunks_long_text_by_size() {
        let text = "palabra ".repeat(2000);
        let chunks = chunk_text(&text);
        assert!(chunks.len() > 1);
        assert!(chunks
            .iter()
            .all(|chunk| chunk.chars().count() <= CHUNK_CHARS));
    }

    #[test]
    #[ignore = "requiere Tesseract y STUDY_PLANNER_OCR_TEST_IMAGE"]
    fn ocr_reads_text_when_configured() {
        let image = std::env::var("STUDY_PLANNER_OCR_TEST_IMAGE")
            .expect("define STUDY_PLANNER_OCR_TEST_IMAGE");
        let (mut db, subject_id, dir) = setup("ocr");
        let outcome = import_document(&mut db, subject_id, &image).expect("importar imagen");

        assert!(outcome.ocr_used, "debe usar OCR");
        assert_eq!(outcome.document.kind, "imagen");
        assert_eq!(outcome.document.extraction_status, "ok");
        assert!(outcome.document.text_chars > 0);
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    #[ignore = "requiere STUDY_PLANNER_PDF_TEST_FILE"]
    fn pdf_reads_text_when_configured() {
        let pdf = std::env::var("STUDY_PLANNER_PDF_TEST_FILE")
            .expect("define STUDY_PLANNER_PDF_TEST_FILE");
        let (mut db, subject_id, dir) = setup("pdf");
        let outcome = import_document(&mut db, subject_id, &pdf).expect("importar pdf");

        assert_eq!(outcome.document.kind, "pdf");
        assert_eq!(outcome.document.extraction_status, "ok");
        assert!(outcome.document.text_chars > 0);
        let _ = std::fs::remove_dir_all(&dir);
    }
}
