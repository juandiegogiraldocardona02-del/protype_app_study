# AGENTS.md — Sistema Inteligente de Planificación de Estudios Offline

> Especificación de Requisitos de Software (SRS) conforme a ISO/IEC/IEEE 29148,
> Descripción de Diseño (IEEE 1016) y Plan de Verificación (IEEE 1028).
> Este archivo es la fuente única de verdad para el desarrollo. OpenCode debe
> construirlo por etapas sin inventar requisitos.

---

## 0. Cómo debe usar OpenCode este archivo

1. Lee la sección completa antes de escribir código.
2. Implementa **por etapas** en el orden de la §12. No avances a la siguiente
   etapa sin que la anterior pase sus criterios de aceptación.
3. Antes de cada commit ejecuta: `cargo fmt`, `cargo clippy -- -D warnings`,
   `cargo test`, `flutter test`.
4. Prohibido añadir dependencias que requieran conexión a Internet en tiempo
   de ejecución. Todo debe funcionar con la red deshabilitada.
5. Si un requisito es ambiguo, **detente y pregunta** antes de asumir.

---

## 1. Propósito y Alcance

Aplicación **offline-first** multiplataforma (Windows, Linux, macOS, Android,
iOS) que integra:
- Planificación académica automática desde documentos y objetivos.
- Aprendizaje con repetición espaciada, flashcards y evaluaciones.
- Gamificación (XP, niveles, rachas, insignias).
- Espacios independientes por asignatura (agenda, archivos, tareas,
  calendario, evaluaciones, progreso por tema).
- Asistente de IA local (sin Internet) para consultas y generación de
  actividades.

**Fuera de alcance v1.0:** sincronización en nube, edición colaborativa,
integraciones con LMS/calendarios externos, reconocimiento de voz en tiempo
real.

---

## 2. Glosario

| Término | Definición |
|---|---|
| Offline-first | Todas las funciones críticas operan sin red. |
| GGUF | Formato de modelo cuantizado para llama.cpp. |
| Q4_K_M | Cuantización 4 bits, línea base recomendada. |
| XP | Puntos de experiencia por actividades académicas. |
| Replanificación | Redistribución automática de sesiones pendientes. |
| Fuente de estudio | Documento del que se extraen contenidos. |
| Dominio de tema | Aprendizaje real medido por evaluaciones y repaso. |
| `.studyplan` | Archivo portable de una asignatura completa. |

---

## 3. Arquitectura Obligatoria (IEEE 1016)

```
raíz/
├── lib/                      # Flutter/Dart — capa de presentación
│   ├── main.dart
│   ├── screens/              # inicio, materias, calendario, biblioteca,
│   │                         # estadísticas, asistente, configuración
│   ├── widgets/
│   ├── state/                # gestión de estado (Riverpod o Bloc)
│   └── bridge/               # bindings generados por flutter_rust_bridge
├── rust/                     # Núcleo de dominio y rendimiento
│   ├── src/
│   │   ├── lib.rs
│   │   ├── bridge.rs         # API expuesta a Flutter (flutter_rust_bridge)
│   │   ├── db/               # SQLite + migraciones versionadas
│   │   ├── planning/         # core-planning
│   │   ├── learning/         # core-learning (SRS, flashcards)
│   │   ├── gamification/     # core-gamification (XP, rachas)
│   │   ├── documents/        # core-documents (importación, OCR, versionado)
│   │   ├── ai/               # core-ai (llama.cpp, whisper.cpp, Tesseract)
│   │   └── backup/           # core-backup (.studyplan, copias globales)
│   ├── migrations/           # SQL de migraciones
│   └── Cargo.toml
├── assets/
│   └── models/               # GGUF (NO versionar; paquetes opcionales)
├── docs/
│   ├── SRS.md                # copia de este archivo
│   └── design/               # diagramas UML
├── test/                     # pruebas Dart
└── AGENTS.md                 # este archivo
```

**Stack obligatorio:**
- UI: **Flutter / Dart** (null safety estricto).
- Núcleo: **Rust** (edición 2021), expuesto vía **`flutter_rust_bridge`**.
- Persistencia: **SQLite** (crate `rusqlite`), migraciones versionadas.
- IA local: **llama.cpp** (modelos **GGUF Q4_K_M**).
- OCR: **Tesseract** (offline).
- Audio: **whisper.cpp** (modelo `tiny` ≈ 75 MB / ~0.4 GB RAM por defecto).
- Sin servidores. Sin llamadas salientes en runtime.

**Comandos:**
```bash
flutter pub get
cd rust && cargo build --release
flutter_rust_bridge_codegen generate   # tras cambios en rust/src/bridge.rs
cargo test        # en rust/
flutter test      # en raíz
cargo fmt && cargo clippy -- -D warnings   # obligatorio antes de commit
```

**Convenciones:**
- Dart: archivos `snake_case.dart`, clases `PascalCase`, sin `dynamic` salvo
  interoperabilidad con el puente FFI.
- Rust: `snake_case`, errores con `thiserror`, sin `unwrap()` en código de
  producción (usar `?` o manejo explícito).
- SQLite: cada migración en `rust/migrations/NNNN_descripcion.sql`,
  inmutable una vez aplicada.
- Todas las escrituras en BD deben ser **transaccionales** (NFR-009).

---

## 4. Modelo de Datos (SQLite)

| Tabla | Campos principales | Relaciones |
|---|---|---|
| `profiles` | id, nombre, config_json | 1:N → subjects |
| `subjects` | id, profile_id, nombre, color, xp_config_json | 1:N → topics, documents, sessions |
| `topics` | id, subject_id, parent_id, nombre, dificultad, dominio REAL | Jerarquía recursiva; 1:N → flashcards |
| `documents` | id, subject_id, ruta_local, tipo, hash, version | 1:N → document_chunks |
| `document_chunks` | id, document_id, texto, seccion | — |
| `sessions` | id, subject_id, topic_id, inicio, duracion_min, estado (pendiente/completada/replanificada) | — |
| `flashcards` | id, topic_id, pregunta, respuesta, intervalo_dias, proxima_revision | — |
| `assessments` | id, subject_id, tipo, puntuacion, fecha | — |
| `xp_log` | id, profile_id, actividad, xp, timestamp | — |
| `change_history` | id, entidad, entidad_id, accion, timestamp | — |

---

## 5. Requisitos Funcionales

Cada requisito incluye criterios de aceptación verificables. Prioridad:
**M**ust / **S**hould / **C**ould.

### FR-001 (M) Perfiles independientes
Crear ≥1 perfil local; datos aislados entre perfiles.
- **Acepta:** dos perfiles en el mismo dispositivo no ven documentos ni
  estadísticas del otro. Cambio de perfil sin reiniciar.

### FR-002 (M) Exportar/importar `.studyplan`
Exporta asignatura completa (temario, calendario, actividades, documentos,
métodos, evaluaciones, estadísticas, config XP); importa offline.
- **Acepta:** archivo generado en dispositivo 1 se importa en dispositivo 2
  conservando histórico. No sobrescribe sin confirmación.

### FR-003 (M) Importación multi-formato
PDF, DOCX, PPTX, XLSX, TXT, PNG/JPG, MP3/WAV/M4A → biblioteca por asignatura.
- **Acepta:** PDF 200 MB importado en <30 s en hardware de referencia (4 GB
  RAM, sin GPU). Imágenes escaneadas pasan por OCR local (Tesseract).

### FR-004 (M) Extracción inteligente de estructura
Tras importar: identificar temas, subtemas, conceptos, fechas, actividades;
proponer plan editable antes de confirmar.
- **Acepta:** temario PDF → jerarquía ≥2 niveles. Todo local, sin red.

### FR-005 (S) Sincronización y versionado de fuentes
Al reimportar documento actualizado (mismo hash de origen), comparar y
proponer diff de temas (nuevos/eliminados/modificados) sin perder dominio.
- **Acepta:** v1 → v2 muestra diff; aplicar conserva dominio en temas no
  modificados; rechazo mantiene plan original.

### FR-006 (M) Generación automática de plan
Con contenidos extraídos + disponibilidad semanal → plan con sesiones,
duraciones y fechas límite.
- **Acepta:** 10 h/sem + 20 temas → plan no excede disponibilidad semanal.
  Revisión y edición antes de guardar.

### FR-007 (M) Replanificación automática
Sesión incumplida → redistribuir pendientes sin destruir calendario original
ni duplicar.
- **Acepta:** 3 sesiones/día, 1 completada → 2 pendientes recolocadas
  respetando fechas límite; notificación; revertible.

### FR-008 (M) Vistas de calendario
Vistas mensual, semanal, diaria; filtro por asignatura; indicadores de estado.
- **Acepta:** cambio de vista <500 ms. Replanificadas visualmente distintas.

### FR-009 (M) Flashcards con repetición espaciada
Generación automática desde contenidos + creación/edición/borrado manual +
algoritmo SRS (SM-2 o equivalente).
- **Acepta:** ≥1 flashcard por concepto identificado; el usuario acepta o
  descarta cada una.

### FR-010 (S) Evaluaciones automáticas
Cuestionarios (opción múltiple, V/F, respuesta corta) desde documentos,
corrección local.
- **Acepta:** capítulo de 10 páginas → ≥8 preguntas sin contenido fuera de la
  fuente. Opción múltiple y V/F automáticos; respuesta corta por similitud
  semántica local con umbral configurable.

### FR-011 (M) Seguimiento de dominio
Indicador por tema basado en evaluaciones + repasos + tiempo efectivo.
- **Acepta:** actualización tras cada evaluación/repaso. Recomendación de
  repaso para temas con dominio bajo.

### FR-012 (M) Sistema de XP configurable
Valores por defecto: leer sección 10, tarea 20, cuestionario aprobado 30,
sesión 15, evaluación 50, racha 7 d 100, dominar tema 150. Configurables.
- **Acepta:** cambios aplican solo a actividades futuras. Saldo en tiempo real.

### FR-013 (S) Niveles, insignias, rachas
Niveles progresivos, insignias por hitos, racha diaria.
- **Acepta:** racha incrementa al completar ≥1 actividad académica en el día
  local; se reinicia si no hay actividad (salvo "congelación" habilitada).

### FR-014 (M) Consultas sobre documentos
Asistente responde usando **exclusivamente** documentos de la asignatura
activa; cita fuente (documento y sección).
- **Acepta:** respuesta <10 s con modelo cuantizado adecuado. Si no hay
  respuesta en fuentes, lo indica explícitamente (no inventa).

### FR-015 (S) Explicación y generación de actividades
Explicar conceptos con ejemplos; generar preguntas, resúmenes, esquemas.
- **Acepta:** explicación con ≥1 ejemplo concreto, vinculada al tema; las
  actividades generadas se añaden al calendario con un clic.

### FR-016 (M) Distinción documental vs. conocimiento general
Toda respuesta marcada: "Fuente: documento X" o "Conocimiento general del
modelo".
- **Acepta:** etiqueta de origen en toda respuesta. El usuario puede
  restringir el asistente a solo documentos.

### FR-017 (M) Biblioteca por asignatura
Documentos organizados, búsqueda por nombre/tipo/asignatura.
- **Acepta:** eliminación con confirmación; flashcards/sesiones derivadas se
  marcan "huérfanas" para revisión (no se borran automáticamente).

### FR-018 (M) Instalación modular de IA
Base sin IA generativa (asignaturas, calendario, biblioteca, flashcards
manuales). Modelos LLM/OCR/transcripción como paquetes opcionales descargables
una vez y 100% offline después.
- **Acepta:** tras instalación base funciona el flujo básico sin modelos. Al
  instalar un GGUF Q4_K_M (1–3 B móvil / 3–8 B escritorio), el asistente se
  habilita sin red.

### FR-019 (M) Copias de seguridad
Exportar/importar todo el dispositivo (perfiles, asignaturas, documentos,
estadísticas, config).
- **Acepta:** exportación con integridad verificable. Restauración en
  dispositivo limpio sin pérdida de progreso.

### FR-020 (C) Historial de cambios
Registrar modificaciones de planes y documentos (quién=local, qué, cuándo).
- **Acepta:** historial con ≥50 cambios por asignatura, con timestamp y tipo.

### FR-021 (S) Modo concentración
Pomodoro, registro de sesiones, silenciado de notificaciones internas no
académicas durante la sesión.
- **Acepta:** sesión Pomodoro silencia distracciones; al final registra tiempo
  efectivo y otorga XP.

### FR-022 (M) Accesibilidad
Escalado de texto, navegación completa por teclado, alto contraste.
- **Acepta:** todos los elementos interactivos alcanzables por teclado en
  escritorio. Escalado no rompe layouts.

---

## 6. Requisitos No Funcionales

| ID | Categoría | Requisito | Verificación |
|---|---|---|---|
| NFR-001 | Rendimiento | UI responde <300 ms en hardware de referencia (4 GB RAM, sin GPU). | Cronometraje de interacción. |
| NFR-002 | Rendimiento | Inferencia LLM Q4_K_M 1–3 B: respuesta inicial <15 s. | Prueba con modelo de referencia. |
| NFR-003 | Offline | 100% de funciones críticas sin red. | Prueba con red deshabilitada. |
| NFR-004 | Privacidad | Ningún dato sale del dispositivo. | Inspección de tráfico + revisión de código. |
| NFR-005 | Portabilidad | Windows 10+, Linux x86_64, macOS 11+, Android 10+, iOS 15+. | Compilación y despliegue por plataforma. |
| NFR-006 | Mantenibilidad | Separación Flutter / Rust / SQLite. | Revisión de estructura del repo. |
| NFR-007 | Instalación | Base ≤500 MB; paquetes IA opcionales y eliminables. | Medición de instalador y paquetes. |
| NFR-008 | Usabilidad | Asignatura → documento → plan en <5 min sin ayuda. | Prueba con usuario representativo. |
| NFR-009 | Fiabilidad | Sin pérdida de datos ante cierre inesperado; escrituras transaccionales. | Corte simulado + verificación de integridad. |
| NFR-010 | Modelos | Acepta GGUF; selecciona cuantización según RAM. | Prueba con Q4_K_M, Q5_K_M, Q8_0. |

---

## 7. Restricciones

- **RES-001:** Sin servicios en la nube para funciones críticas.
- **RES-002:** UI en Flutter/Dart; núcleo en Rust vía `flutter_rust_bridge`.
- **RES-003:** SQLite local, sin servidores de BD.
- **RES-004:** LLM local con llama.cpp (GGUF). Móvil: 1–3 B Q4_K_M.
  Escritorio: 3–8 B Q4_K_M. Sin GPU requerida.
- **RES-005:** OCR con Tesseract offline; audio con whisper.cpp (`tiny` por
  defecto ≈ 75 MB / ~0.4 GB RAM).
- **RES-006:** No inventar plantillas IEEE; referenciar 29148, 1016, 1028.

---

## 8. Interfaces

- **UI principal:** Inicio · Mis materias · Calendario · Biblioteca ·
  Estadísticas · Asistente IA · Configuración.
- **Espacio de asignatura:** Agenda · Archivos · Tareas · Calendario propio ·
  Evaluaciones · Progreso por tema.
- **Entradas:** PDF, DOCX, PPTX, XLSX, TXT, PNG, JPG, MP3, WAV, M4A.
- **Salidas:** `.studyplan` (asignatura) y copia de seguridad global
  (comprimida).
- **Hardware:** ≥4 GB RAM escritorio / ≥3 GB móvil; GPU no requerida.

---

## 9. Criterios de Aceptación Globales (v1.0)

1. Todos los FR **Must** implementados y verificados.
2. NFR-003 (offline) y NFR-004 (privacidad) verificados con resultados
   conformes.
3. Ejecución en ≥3 plataformas (Windows, Linux, Android) sin errores
   bloqueantes.
4. Este `AGENTS.md` describe correctamente arquitectura, comandos, convenciones
   y verificación, de modo que un agente continúe sin conocimiento tácito.

---

## 10. Verificación (IEEE 1028)

| Revisión | Momento | Objetivo |
|---|---|---|
| Requisitos | Antes de implementar | FR/NFR verificables y no ambiguos. |
| Código | Por módulo | Sin violaciones de arquitectura, fugas de memoria, deps prohibidas. |
| Usabilidad | Tras v1 funcional | Flujo "asignatura → documento → plan" <5 min. |
| Privacidad/offline | Antes de cada release | Sin tráfico saliente no autorizado; funciona sin red. |
| Rendimiento | Hardware de referencia | Cumple NFR-001 y NFR-002. |

---

## 11. Decisiones de Diseño Clave

- **Modelo IA escalonado:** móvil 1–3 B Q4_K_M (1–2.5 GB RAM); escritorio
  3–8 B Q4_K_M (2.5–6 GB RAM). Viable en 4 GB sin GPU.
- **Módulos opcionales:** base sin Tesseract/whisper.cpp. Se descargan una vez
  y operan offline.
- **Versionado por hash:** al importar, calcular hash de contenido; si coincide
  con un documento de la misma asignatura, activar FR-005.
- **FFI seguro:** `rust/src/bridge.rs` es el único punto de contacto Rust↔Dart.

---

## 12. Plan de Implementación por Etapas (orden obligatorio)

| Etapa | Entregable verificable | FR cubiertos |
|---|---|---|
| **E1** | Perfiles + asignaturas + SQLite persistente, sin IA. | FR-001, NFR-003, NFR-009 |
| **E2** | Importación PDF/TXT/imágenes + OCR básico + biblioteca por asignatura. | FR-003, FR-017, RES-005 |
| **E3** | Generación de plan, vistas de calendario, replanificación básica. | FR-006, FR-007, FR-008 |
| **E4** | Flashcards + repetición espaciada + dominio por tema. | FR-009, FR-011 |
| **E5** | XP configurable, rachas, niveles. | FR-012, FR-013 |
| **E6** | Asistente IA local (GGUF Q4_K_M) con distinción de fuentes. | FR-014, FR-016, RES-004 |
| **E7** | Exportación/importación `.studyplan` + copia global. | FR-002, FR-019 |
| **E8** | whisper.cpp (audio) + análisis avanzado + evaluación automática. | FR-003 (audio), FR-010, RES-005 |

**Checklist por etapa (debe cumplirse antes de avanzar):**
1. `cargo test` 100% verde.
2. `flutter test` 100% verde.
3. Prueba manual del flujo de la etapa.
4. Prueba con red deshabilitada.
5. Commit con mensaje `feat(E{n}): <resumen>`.

---

## 13. Supuestos y Dependencias

- 4 GB RAM escritorio / 3 GB móvil para modelos de 1–3 B Q4_K_M.
- Paquetes GGUF y binarios de OCR/audio se distribuyen vía repositorio local o
  USB; nunca desde nube en uso normal.
- Dependencias: `flutter_rust_bridge`, `rusqlite`, `llama.cpp`, `Tesseract`,
  `whisper.cpp`, `thiserror`, `serde`, `chrono`.

---

## 14. Anti-patrones prohibidos

- ❌ Llamadas HTTP en runtime (aunque sean opcionales).
- ❌ `unwrap()` en Rust de producción.
- ❌ Migraciones SQLite editadas tras aplicarse.
- ❌ Lógica de dominio en Dart (va en Rust).
- ❌ Modelos GGUF versionados en el repo (usar `assets/models/.gitignore`).
- ❌ Dependencias que exijan cuenta o API key.
- ❌ Inventar requisitos o "mejorar" el alcance sin actualizar este archivo.

---

## 15. Protocolo de dudas

Si un requisito es ambiguo o entra en conflicto con otro:
1. Detén la implementación de esa parte.
2. Anota la duda en `docs/questions.md` con: requisito afectado, opciones,
   recomendación y criterio.
3. Continúa con las partes no bloqueadas.
4. **No** implementes una suposición silenciosa.

---

*Fin del AGENTS.md. Este archivo es la especificación IEEE 29148 del sistema,
lista para que OpenCode construya la aplicación por etapas sin inventar
requisitos.*