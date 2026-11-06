ALTER TABLE documents ADD COLUMN nombre TEXT NOT NULL DEFAULT '';

ALTER TABLE documents ADD COLUMN extraccion_estado TEXT NOT NULL DEFAULT 'pendiente';

ALTER TABLE documents ADD COLUMN extraccion_mensaje TEXT;

UPDATE documents SET nombre = ruta_local WHERE nombre = '';

CREATE INDEX idx_documents_subject_name ON documents(subject_id, nombre);
