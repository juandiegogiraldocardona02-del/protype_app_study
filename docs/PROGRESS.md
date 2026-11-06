# PROGRESS — Estado de implementación

> Documento de continuidad para retomar el trabajo aunque se reinicie la sesión
> o se agoten los tokens. La fuente de requisitos es `AGENTS.md` / `docs/SRS.md`.
> Última actualización: Etapas E1, E2 y E3 completadas, E4 como siguiente paso.

## Repositorio

- GitHub: https://github.com/juandiegogiraldocardona02-del/protype_app_study
- Rama principal: `main`
- Primer commit: `feat(E1): perfiles, asignaturas y persistencia SQLite offline`

## Entorno local (Windows)

- Flutter SDK: `C:\Users\juand\flutter` (añadido al PATH de usuario).
  Si `flutter` no aparece en una terminal nueva, reiníciala.
- Rust: toolchain `stable-x86_64-pc-windows-msvc`.
- Visual Studio 2022 Community con workload *Desktop development with C++*
  (necesario para `flutter build windows`).
- Generador de bindings: `flutter_rust_bridge_codegen 2.13.0`
  (en `C:\Users\juand\.cargo\bin`).
- Tesseract: **opcional**, no instalado por defecto. El OCR se activa si el
  binario `tesseract` está en PATH o en `TESSERACT_PATH`.

## Comandos de verificación obligatorios

```powershell
cd rust
cargo fmt
cargo clippy --all-targets -- -D warnings
cargo test

cd ..
flutter analyze
flutter test
flutter build windows --debug

# Tras cambiar rust/src/bridge.rs:
flutter_rust_bridge_codegen generate
```

## Etapa E1 — COMPLETADA ✅

Cubre FR-001, NFR-003, NFR-009.

- [x] Estructura Flutter + Rust + SQLite según §3.
- [x] Migración `rust/migrations/0001_init.sql` con todo el modelo de §4.
- [x] CRUD de perfiles y asignaturas en Rust (`rust/src/db/mod.rs`).
- [x] Aislamiento de datos por perfil y borrado en cascada.
- [x] Escrituras transaccionales e historial de cambios (`change_history`).
- [x] API FFI única en `rust/src/bridge.rs` + bindings en `lib/bridge/`.
- [x] UI: onboarding, cambio de perfil sin reiniciar, inicio, Mis materias,
      espacios de asignatura y secciones principales.
- [x] `cargo test`: 9 pruebas verdes.
- [x] `flutter test`: 5 pruebas verdes.
- [x] `flutter build windows --debug` y arranque real verificados.

## Etapa E2 — COMPLETADA ✅

Cubre FR-003 (PDF/TXT/imágenes), FR-017 y RES-005.

- [x] Migración `0002_documents_nombre.sql` (nombre, estado y mensaje de
      extracción, índice de búsqueda).
- [x] Módulo Rust `rust/src/documents/mod.rs`: hash SHA-256 por streaming,
      detección de tipo, extracción TXT/PDF, OCR opcional con Tesseract,
      chunking, versionado y CRUD.
- [x] API FFI: `importDocument`, `listDocuments`, `deleteDocument`,
      `ocrAvailable`; bindings regenerados.
- [x] Flutter: biblioteca reutilizable por asignatura (`DocumentLibrary`) en
      Mis materias → Archivos y en Biblioteca global, con búsqueda por nombre,
      filtro por tipo, importación multiarchivo y borrado con confirmación.
- [x] Pruebas Rust: 18 verdes + 2 de integración opcionales verificadas
      manualmente (OCR y PDF reales).
- [x] Pruebas Flutter: 8 verdes.
- [x] `flutter build windows --debug` y arranque real verificados (migración
      `0002` aplicada sin errores).

## Etapa E3 — COMPLETADA ✅

Cubre FR-006 (generación de plan), FR-007 (replanificación) y FR-008 (vistas de
calendario).

- [x] Migración `0003_planning.sql`: `plan_settings`, `availability` y columna
      `sessions.inicio_original` para poder revertir la replanificación.
- [x] Rust `planning`: generación que respeta minutos por día y fecha límite,
      reparto por dificultad (1–3 sesiones por tema), vista previa sin guardar
      y guardado transaccional que conserva las sesiones completadas.
- [x] Replanificación de pendientes desde “ahora”, descontando el tiempo ya
      ocupado por sesiones completadas; reversible con `inicio_original`.
- [x] CRUD de temas (nombre + dificultad 1–5) y configuración de
      disponibilidad (duración, días, minutos/día, hora de inicio, fecha
      límite) desde la agenda de la asignatura.
- [x] Flutter: pestaña Agenda con temas, configuración, vista previa editable
      (se pueden descartar sesiones) y botón de replanificar con “Deshacer”.
- [x] Calendario global con vistas mensual, semanal y diaria, filtro por
      asignatura, indicadores de estado y marcado de sesiones completadas.
- [x] Pruebas Rust: 25 verdes (+2 de integración opcionales).
- [x] Pruebas Flutter: 11 verdes.
- [x] Build Windows y arranque real verificados (migración `0003` aplicada).

## Decisiones de implementación tomadas

- **OCR opcional (FR-018):** se invoca el binario externo `tesseract` si está
  disponible. Si no, la imagen se importa igualmente y se avisa de que no se
  extrajo texto. No se añade ninguna llamada de red.
- **PDF:** extracción de texto con el crate `pdf-extract` (100 % local).
- **Duplicados:** si un documento de la misma asignatura tiene el mismo hash,
  no se vuelve a insertar; se devuelve el existente.
- **Versionado:** un mismo nombre con contenido distinto incrementa `version`.
- **Búsqueda de biblioteca:** filtrado local por nombre y tipo dentro de la
  asignatura (sin consultas de red).
- **OCR verificado:** se extrajo un Tesseract 5.4 portátil en la carpeta
  temporal (`TESSERACT_PATH` + `TESSDATA_PREFIX`) y se ejecutó la prueba
  `ocr_reads_text_when_configured`. No es necesario instalarlo en el sistema:
  la app lo detecta por PATH o por `TESSERACT_PATH`. El idioma OCR se puede
  fijar con `TESSERACT_LANG` (por defecto, el de Tesseract).
- **Planificador:** una sesión por tema como mínimo; dificultad 2 añade una
  sesión y dificultad ≥3 añade dos (máximo 3 por tema). Se reparte de lunes a
  domingo según la disponibilidad configurada y la hora de inicio; si no cabe
  antes de la fecha límite se rechaza con un mensaje claro.
- **Guardado del plan:** reemplaza solo las sesiones no completadas de la
  asignatura (nunca borra el histórico completado).
- **Replanificación:** recoloca todas las pendientes desde el momento actual,
  respetando capacidad diaria menos el tiempo ya usado por sesiones
  completadas. Guarda `inicio_original` para poder deshacer el último cambio.
- **Calendario:** el rango se consulta a Rust por fechas ISO; las vistas
  mensual/semanal/diaria son locales y no hacen peticiones de red.

## Verificación de E3 (resultados)

- `cargo fmt` + `cargo clippy --all-targets -- -D warnings`: limpio.
- `cargo test`: 25 pruebas verdes, 2 ignoradas (integración opcional de E2).
- `flutter analyze`: 0 incidencias.
- `flutter test`: 11 pruebas verdes.
- `flutter build windows --debug`: correcto.
- Arranque real del `.exe` durante 10 s: proceso vivo (migración `0003`).

## Verificación de E2 (resultados)

- `cargo fmt` + `cargo clippy --all-targets -- -D warnings`: limpio.
- `cargo test`: 18 pruebas verdes, 2 ignoradas (integración opcional).
- `cargo test ocr_reads_text_when_configured -- --ignored`: verde con imagen
  PNG real generada localmente.
- `cargo test pdf_reads_text_when_configured -- --ignored`: verde con un PDF
  real.
- `flutter analyze`: 0 incidencias.
- `flutter test`: 8 pruebas verdes.
- `flutter build windows --debug`: correcto.
- Arranque real del `.exe` durante 10 s: proceso vivo (migración aplicada).

## Cómo retomar (para el siguiente agente/sesión)

1. Leer `AGENTS.md` completo y este archivo.
2. Revisar `git log --oneline -10` y `git status`.
3. Continuar en la primera casilla sin marcar de la etapa en curso.
4. Ejecutar la batería de comandos de verificación antes de cada commit.
5. Mantener actualizado este archivo al terminar cada etapa.

## Pendiente por etapas (según §12)

- E4: flashcards, SRS y dominio por tema (FR-009/011).
- E5: XP, rachas y niveles (FR-012/013).
- E6: asistente IA local GGUF (FR-014/016, RES-004).
- E7: `.studyplan` y copias globales (FR-002/019).
- E8: audio whisper.cpp y evaluaciones automáticas (FR-010, RES-005).
