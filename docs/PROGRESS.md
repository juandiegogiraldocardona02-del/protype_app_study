# PROGRESS — Estado de implementación

> Documento de continuidad para retomar el trabajo aunque se reinicie la sesión
> o se agoten los tokens. La fuente de requisitos es `AGENTS.md` / `docs/SRS.md`.
> Última actualización: Etapas E1–E6 completadas, E7 como siguiente paso.

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
- LLVM/libclang 23.1.5 en `C:\Program Files\LLVM\bin` (necesario para compilar
  `llama-cpp-sys-2` con bindgen). Añadir al PATH y definir
  `LIBCLANG_PATH=C:\Program Files\LLVM\bin` antes de compilar Rust.
- **Smart App Control** bloquea binarios sin firmar ejecutados desde OneDrive
  (`os error 4551`). Por eso `rust/target` es una unión (junction) a
  `C:\Users\juand\AppData\Local\Temp\opencode\cargo-target`, y las compilaciones
  de Flutter deben usar
  `STUDY_PLANNER_CARGOKIT_TEMP_DIR=C:\Users\juand\AppData\Local\Temp\opencode\cargokit-temp`
  (soporte añadido en `rust_builder/cargokit/cmake/cargokit.cmake`).
- Modelo de prueba E6: `assets/models/qwen2.5-1.5b-instruct-q4_k_m.gguf`
  (1,1 GB, no versionado). También se puede definir
  `STUDY_PLANNER_MODEL_PATH` o colocar cualquier `.gguf` en la carpeta de
  modelos.

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

## Etapa E4 — COMPLETADA ✅

Cubre FR-009 (flashcards y repetición espaciada) y FR-011 (dominio por tema).

- [x] Migración `0004_learning.sql`: columnas SM-2 en `flashcards`
      (`repasos`, `factor_facilidad`, `ultima_revision`, `origen`) y tabla
      `review_log` para conservar el historial de repasos.
- [x] Algoritmo SM-2 en Rust: intervalos 1 → 6 → intervalo × factor; un repaso
      con calidad < 3 reinicia repeticiones y reduce el factor (límites
      1,3–3,0).
- [x] CRUD de flashcards manual con validación y borrado en cascada por tema.
- [x] Generación de propuestas desde los temas y fragmentos de documentos:
      busca una frase que mencione el tema y propone pregunta/respuesta con
      fuente; si no hay fuente, lo indica para revisión. El usuario acepta o
      descarta cada propuesta antes de guardar.
- [x] Repaso guiado en Flutter: pregunta → mostrar respuesta → valorar
      (Otra vez/Difícil/Bien/Fácil); las tarjetas repasadas se reprograman.
- [x] Dominio por tema (0–1) = 60 % media de los últimos 5 repasos + 40 % de
      tiempo efectivo completado (máx. 120 min); se recalcula al repasar y al
      completar una sesión. La UI sugiere repasar temas con dominio bajo.
- [x] Pestaña Progreso con dominio por tema, tarjetas pendientes/totales,
      revisión, creación manual, edición, borrado y generación propuesta.
- [x] Pruebas Rust: 32 verdes (+2 de integración opcionales).
- [x] Pruebas Flutter: 14 verdes.
- [x] Build Windows y arranque real verificados (migración `0004` aplicada).

## Etapa E5 — COMPLETADA ✅

Cubre FR-012 (XP configurable) y FR-013 (niveles, insignias y rachas).

- [x] Migración `0005_gamification.sql`: tabla `streaks` por perfil con racha
      actual, mejor racha, último día de actividad, congelación y día usado.
- [x] Rust `gamification`: configuración de XP por asignatura guardada en
      `subjects.xp_config_json` (sección 10, tarea 20, cuestionario 30, sesión
      15, evaluación 50, racha de 7 días 100, tema dominado 150); validación
      0–10000.
- [x] XP se otorga una sola vez por sesión completada (`sesion:{id}`), por tema
      dominado (`dominar_tema:{id}`, dominio ≥ 0,8) y por hitos de racha de 7
      días. Cambiar la configuración solo afecta a actividades futuras.
- [x] Rachas: una actividad académica al día (sesión o repaso); se reinicia si
      se rompe la secuencia; congelación opcional cubre un día perdido por mes.
- [x] Niveles progresivos: nivel 1 en 0 XP y 100 XP adicionales por nivel
      (100, 300, 600…). Insignias dinámicas por repasos, sesiones, racha,
      nivel y temas dominados.
- [x] API FFI: `getXpConfig`, `saveXpConfig`, `getGamificationSummary`;
      bindings regenerados.
- [x] Flutter: tarjeta de nivel/racha en Inicio, pantalla Estadísticas con XP,
      progreso de nivel e insignias, y configuración de XP por asignatura en
      la pestaña Progreso.
- [x] Pruebas Rust: 40 verdes (+2 de integración opcionales).
- [x] Pruebas Flutter: 17 verdes.
- [x] Build Windows y arranque real verificados (migración `0005` aplicada).

## Etapa E6 — COMPLETADA ✅

Cubre FR-014 (consultas sobre documentos), FR-016 (distinción documental vs.
conocimiento general) y RES-004 (LLM local GGUF Q4_K_M).

- [x] Dependencia `llama-cpp-2 0.1.161` (sin features por defecto) y modelo
      Qwen2.5-1.5B-Instruct Q4_K_M descargado como paquete opcional fuera del
      repositorio.
- [x] Rust `ai`: detección del modelo (env, carpeta de modelos junto a la BD,
      `assets/models` y carpeta del ejecutable), estado del asistente, carga
      perezosa con caché en memoria y generación con llama.cpp (contexto 4096,
      máx. 256 tokens nuevos, hilos limitados a 8).
- [x] Recuperación léxica local: normaliza acentos, descarta palabras vacías,
      puntúa fragmentos por ocurrencias, selecciona hasta 3 (máx. 2 por
      documento) y construye un extracto centrado en la consulta.
- [x] Prompt ChatML: con fragmentos exige responder solo con ellos, citar
      `[Fuente: nombre]` y rechazar explícitamente si no está en el material;
      sin fragmentos marca la respuesta como conocimiento general del modelo.
- [x] Si “Solo documentos” está activo y no hay coincidencias, se devuelve un
      rechazo sin cargar el modelo (no inventa y no gasta recursos).
- [x] API FFI: `getAiStatus` (síncrona), `askAssistant` y DTOs
      `AiStatusDto`, `AssistantSourceDto`, `AssistantAnswerDto`; bindings
      regenerados.
- [x] Flutter: pantalla Asistente IA con estado del modelo, selector de
      asignatura, interruptor “Solo documentos”, pregunta, respuesta con
      etiqueta de origen y fuentes citadas (nombre + extracto).
- [x] Pruebas Rust: 43 verdes + 3 ignoradas; la de inferencia real
      (`answers_from_documents_with_local_model`) verificada manualmente con el
      modelo Qwen2.5 (respuesta en ~4,4 s).
- [x] Pruebas Flutter: 20 verdes (incluye aviso sin modelo, respuesta citada y
      conocimiento general).
- [x] Build Windows y arranque real verificados.

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
- **SM-2:** se usa la calidad 0–5 del repaso. La tarjeta nueva vence de
  inmediato; los repasos con calidad < 3 reinician la secuencia. El factor de
  facilidad se limita a 1,3–3,0 para evitar intervalos descontrolados.
- **Generación de tarjetas:** sin LLM (etapa E6), se propone una tarjeta por
  tema usando la frase de los documentos que menciona el tema. Si no hay
  coincidencia, se propone una tarjeta marcada como «sin fuente» para que el
  usuario la edite o la descarte. Nada se guarda sin confirmación.
- **Dominio:** media de los últimos 5 repasos (60 %) y minutos efectivos de
  sesiones completadas (40 %, tope 120 min). Las evaluaciones se integrarán en
  la etapa E8; entonces se ampliará la fórmula sin cambiar el esquema.
- **XP configurable:** cada asignatura guarda sus valores en
  `subjects.xp_config_json`; Rust los valida (0–10000) y los lee en el momento
  de otorgar el XP, por lo que un cambio no recalcula el histórico. El registro
  `xp_log` usa claves idempotentes (`sesion:{id}`, `dominar_tema:{id}`) para no
  duplicar premios.
- **Rachas:** se registra actividad al completar una sesión o repasar una
  tarjeta; solo cuenta la primera del día local. La congelación opcional cubre
  como máximo un día perdido por mes natural. Cada 7 días seguidos se otorga
  el XP de racha una sola vez por hito.
- **Niveles e insignias:** nivel 1 empieza en 0 XP y cada nivel exige 100 XP
  más que el anterior. Las insignias se calculan al consultar el resumen
  (repaso, sesión, racha de 7, nivel 5, tema dominado y diez repasos), sin
  almacenar estado redundante.
- **Historial:** cada repaso queda en `review_log` con calidad, intervalo y
  factor, lo que permite recalcular el dominio y auditar la evolución.
- **LLM local (E6):** se integra `llama-cpp-2` (bindings oficiales de
  llama.cpp) sin servidores ni llamadas de red. El backend se inicializa una
  sola vez por proceso y los logs nativos se silencian.
- **Modelo opcional:** la instalación base sigue funcionando sin IA. El modelo
  se busca por `STUDY_PLANNER_MODEL_PATH`, `STUDY_PLANNER_MODELS_DIR`,
  `<carpeta de la BD>/models`, `assets/models` junto al directorio actual o al
  ejecutable. Se usa el primer `.gguf` encontrado.
- **Recuperación sin embeddings:** para no exigir otro modelo, la selección de
  contexto es léxica y local (normalización + palabras vacías + ocurrencias).
  Es suficiente para fragmentos de apuntes y mantiene el consumo bajo.
- **Anti-alucinación:** con “Solo documentos” activo, si ningún fragmento
  coincide se devuelve un mensaje de rechazo explícito sin invocar al modelo.
  Con conocimiento general, la UI etiqueta la respuesta como tal y no muestra
  fuentes.
- **Rendimiento:** Qwen2.5-1.5B Q4_K_M respondió en ~4,4 s en el hardware de
  desarrollo, por debajo del objetivo de 15 s (NFR-002). La primera consulta
  incluye la carga del modelo; las siguientes reutilizan la caché.
- **Build en Windows con Smart App Control:** los binarios generados dentro de
  OneDrive son bloqueados al ejecutarse. Se usa una junction para `rust/target`
  y la variable `STUDY_PLANNER_CARGOKIT_TEMP_DIR` para el target de Cargokit.

## Verificación de E6 (resultados)

- `cargo fmt` + `cargo clippy --all-targets -- -D warnings`: limpio.
- `cargo test`: 43 pruebas verdes, 3 ignoradas (OCR, PDF y modelo local).
- `cargo test answers_from_documents_with_local_model -- --ignored`: verde con
  Qwen2.5-1.5B Q4_K_M (~4,4 s), citando `study_planner_ai_test.txt`.
- `flutter analyze`: 0 incidencias.
- `flutter test`: 20 pruebas verdes.
- `flutter build windows --debug`: correcto.
- Arranque real del `.exe` durante 10 s: proceso vivo.

## Verificación de E5 (resultados)

- `cargo fmt` + `cargo clippy --all-targets -- -D warnings`: limpio.
- `cargo test`: 40 pruebas verdes, 2 ignoradas (integración opcional de E2).
- `flutter analyze`: 0 incidencias.
- `flutter test`: 17 pruebas verdes.
- `flutter build windows --debug`: correcto.
- Arranque real del `.exe` durante 10 s: proceso vivo (migración `0005`).

## Verificación de E4 (resultados)

- `cargo fmt` + `cargo clippy --all-targets -- -D warnings`: limpio.
- `cargo test`: 32 pruebas verdes, 2 ignoradas (integración opcional de E2).
- `flutter analyze`: 0 incidencias.
- `flutter test`: 14 pruebas verdes.
- `flutter build windows --debug`: correcto.
- Arranque real del `.exe` durante 10 s: proceso vivo (migración `0004`).

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

- E7: `.studyplan` y copias globales (FR-002/019).
- E8: audio whisper.cpp y evaluaciones automáticas (FR-010, RES-005).
