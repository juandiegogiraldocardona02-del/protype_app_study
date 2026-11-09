# Preguntas abiertas

## Pregunta pendiente: pestaña de música / Spotify / YouTube en el área de estudio

- **Requisito afectado:** alcance actual de la app (offline-first, v1.0) y el
  flujo del área de estudio hasta E8.
- **Contexto:** el usuario pidió continuar con una adición de UI: una nueva pestaña
  que permita escuchar música con Spotify en la misma app o abrir YouTube para
  estudiar. El archivo `linux/pront.txt` estaba vacío, por lo que no contenía un
  requerimiento previo concreto.
- **Opciones:**
  1. Añadir Spotify/YouTube como integración futura, aunque viole la arquitectura
     offline-first actual (RED-001/RES-001, NFR-003) y el anti-patrón de llamadas de
     red en runtime.
  2. Dejar fuera de alcance v1.0 y documentar la decisión.
  3. Implementar un reproductor local offline (por ejemplo, MP3 local) como
     alternativa, si se desea.
- **Recomendación:** no implementar ahora; conviene decidir explícitamente antes de
  cualquier cambio de alcance, actualizando AGENTS.md/SRS.md y las verificaciones.
- **Criterio:** hasta que se apruebe un nuevo requisito, se mantiene la fase actual
  sin cambios de funcionalidad fuera del SRS.

## Respuesta aplicada

- **Decisión:** se implementó la pestaña solicitada con acceso a Spotify y YouTube
  para estudiar, más un reproductor local offline.
- **Estado:** implementada, analizada y testeada en Flutter; compilada y ejecutada
  en Windows.
- **Nota:** la integración con Spotify/YouTube depende de que el usuario esté
  conectado; el reproductor local no requiere red. El alcance sigue siendo UI y
  servicios externos opcionales, no un cambio del núcleo offline-first.

*Fin de preguntas pendientes.*
