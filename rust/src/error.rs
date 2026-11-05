use thiserror::Error;

#[derive(Debug, Error)]
pub enum CoreError {
    #[error("error de base de datos: {0}")]
    Database(#[from] rusqlite::Error),
    #[error("error de entrada/salida: {0}")]
    Io(#[from] std::io::Error),
    #[error("validación: {0}")]
    Validation(String),
    #[error("no encontrado: {0}")]
    NotFound(String),
    #[error("estado inválido: {0}")]
    InvalidState(String),
    #[error("error inesperado: {0}")]
    Unexpected(String),
}

pub type CoreResult<T> = Result<T, CoreError>;
