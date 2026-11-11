import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_sections.dart';
import '../state/providers.dart';
import '../state/repository.dart' show SubjectDto;
import '../widgets/empty_state.dart';
import 'subject_space_screen.dart';

enum StudyTarget {
  subjects,
  home,
  calendar,
  assistant,
  subjectFiles,
  subjectMusic,
  subjectProgress,
  subjectAssessments,
  subjectClassStart,
}

extension StudyTargetIcon on StudyTarget {
  IconData get icon {
    switch (this) {
      case StudyTarget.subjects:
        return Icons.menu_book_outlined;
      case StudyTarget.home:
        return Icons.home_outlined;
      case StudyTarget.calendar:
        return Icons.calendar_month_outlined;
      case StudyTarget.assistant:
        return Icons.smart_toy_outlined;
      case StudyTarget.subjectFiles:
        return Icons.folder_open_outlined;
      case StudyTarget.subjectMusic:
        return Icons.music_note_outlined;
      case StudyTarget.subjectProgress:
        return Icons.insights_outlined;
      case StudyTarget.subjectAssessments:
        return Icons.quiz_outlined;
      case StudyTarget.subjectClassStart:
        return Icons.school_outlined;
    }
  }
}

class StudyAction {
  const StudyAction({required this.label, required this.target});

  final String label;
  final StudyTarget target;
}

class StudyStep {
  const StudyStep({
    required this.title,
    required this.duration,
    required this.description,
    required this.action,
    this.tips = const <String>[],
  });

  final String title;
  final String duration;
  final String description;
  final StudyAction action;
  final List<String> tips;
}

class StudyPhase {
  const StudyPhase({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.steps,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<StudyStep> steps;
}

const List<StudyPhase> _phases = <StudyPhase>[
  StudyPhase(
    title: 'Fase 1 · Preparación',
    subtitle: 'Prepara cuerpo, mente y material · 15 min',
    icon: Icons.self_improvement,
    steps: <StudyStep>[
      StudyStep(
        title: 'Define tu objetivo',
        duration: '3 min',
        description:
            'Escribe en una frase qué quieres saber al terminar y conviértelo '
            'en 3 preguntas concretas. Tu cerebro aprende mejor cuando sabe '
            'qué buscar.',
        tips: <String>[
          'Una sola asignatura y un solo tema por sesión.',
          'Objetivo medible: «explicar X sin mirar los apuntes».',
        ],
        action: StudyAction(
          label: 'Ir a Mis materias',
          target: StudyTarget.subjects,
        ),
      ),
      StudyStep(
        title: 'Prepara material y espacio',
        duration: '5 min',
        description:
            'Ten a mano el documento, el cuaderno y agua. Busca luz natural, '
            'postura erguida y silencia las notificaciones.',
        tips: <String>[
          'Mesa despejada: solo el material de esta sesión.',
          'Móvil en modo avión o fuera de la mesa.',
        ],
        action: StudyAction(
          label: 'Abrir Archivos',
          target: StudyTarget.subjectFiles,
        ),
      ),
      StudyStep(
        title: 'Entra en estado de aprendizaje',
        duration: '7 min',
        description:
            'Respira 4 segundos inhalando, 4 reteniendo y 6 exhalando durante '
            '2 minutos. Pon música barroca a ~60 ppm y visualiza el objetivo '
            'cumplido.',
        tips: <String>[
          'Música instrumental, sin letra y a volumen bajo.',
          'Repite una sugerencia positiva: «puedo aprender esto».',
        ],
        action: StudyAction(
          label: 'Abrir Música',
          target: StudyTarget.subjectMusic,
        ),
      ),
    ],
  ),
  StudyPhase(
    title: 'Fase 2 · Entrada',
    subtitle: 'Recibe la información con curiosidad y ritmo · 40 min',
    icon: Icons.visibility_outlined,
    steps: <StudyStep>[
      StudyStep(
        title: 'Macrolectura: el mapa completo',
        duration: '8 min',
        description:
            'Recorre títulos, índice, negritas, imágenes, gráficos y '
            'conclusiones. No subrayes todavía: solo construye el mapa mental '
            'del tema.',
        tips: <String>[
          'Lee de 2 a 3 veces más rápido de lo normal.',
          'Marca con un punto las zonas que no entiendas.',
        ],
        action: StudyAction(
          label: 'Abrir documento',
          target: StudyTarget.subjectFiles,
        ),
      ),
      StudyStep(
        title: 'Formula preguntas',
        duration: '5 min',
        description:
            'Convierte cada título y subtítulo en una pregunta. Las preguntas '
            'activan la búsqueda de respuestas y mejoran la retención.',
        tips: <String>[
          'Usa qué, cómo, por qué, para qué y cuál es la diferencia.',
          'Anota al menos 8 preguntas antes de leer en detalle.',
        ],
        action: StudyAction(
          label: 'Preguntar al asistente',
          target: StudyTarget.assistant,
        ),
      ),
      StudyStep(
        title: 'Lectura activa en bloques',
        duration: '25 min',
        description:
            'Lee en dos bloques de 12 minutos con 1 minuto de pausa entre '
            'ellos. Busca las respuestas a tus preguntas, subraya como máximo '
            'el 20 % y anota las dudas al margen.',
        tips: <String>[
          'Una idea por párrafo: resúmela con tus propias palabras.',
          'Si te pierdes, vuelve al título y pregunta qué aporta.',
        ],
        action: StudyAction(
          label: 'Abrir Archivos',
          target: StudyTarget.subjectFiles,
        ),
      ),
      StudyStep(
        title: 'Pausa activa',
        duration: '2 min',
        description:
            'Levántate, estira el cuello y la espalda, bebe agua y mira algo '
            'lejano. Las pausas consolidan y evitan la fatiga.',
        tips: <String>[
          'Sin pantallas: la pausa debe descansar la vista y la mente.',
        ],
        action: StudyAction(
          label: 'Abrir temporizador',
          target: StudyTarget.subjectClassStart,
        ),
      ),
    ],
  ),
  StudyPhase(
    title: 'Fase 3 · Procesamiento',
    subtitle: 'Convierte la información en conocimiento propio · 35 min',
    icon: Icons.psychology_outlined,
    steps: <StudyStep>[
      StudyStep(
        title: 'Escucha activa (si hay audio)',
        duration: '15 min',
        description:
            'Escucha en tres pasadas: relajado, siguiendo el texto y sin texto '
            'intentando anticipar la siguiente idea. Si no hay audio, lee el '
            'texto en voz alta con ritmo.',
        tips: <String>[
          'No pauses en la primera pasada; solo anota las dudas.',
          'La tercera pasada es la que más consolida.',
        ],
        action: StudyAction(
          label: 'Abrir Archivos',
          target: StudyTarget.subjectFiles,
        ),
      ),
      StudyStep(
        title: 'Mapa mental o resumen visual',
        duration: '10 min',
        description:
            'En una sola hoja coloca la idea central y ramifica conceptos, '
            'ejemplos y relaciones con flechas y colores. No copies literal: '
            'transforma la información.',
        tips: <String>[
          'Usa palabras clave, no frases completas.',
          'Incluye al menos un ejemplo por rama principal.',
        ],
        action: StudyAction(
          label: 'Pedir esquema al asistente',
          target: StudyTarget.assistant,
        ),
      ),
      StudyStep(
        title: 'Recitación activa',
        duration: '10 min',
        description:
            'Cierra el material y explica el tema en voz alta como si lo '
            'enseñaras. Después abre el documento y corrige lo que hayas '
            'olvidado.',
        tips: <String>[
          'Si te bloqueas, anota la pregunta y sigue; luego vuelve.',
          'Hablar obliga a recuperar, no solo a reconocer.',
        ],
        action: StudyAction(
          label: 'Repasar tarjetas',
          target: StudyTarget.subjectProgress,
        ),
      ),
      StudyStep(
        title: 'Autoevaluación',
        duration: '10 min',
        description:
            'Genera preguntas sobre el tema y respóndelas sin mirar. Marca los '
            'fallos y conviértelos en nuevas preguntas de repaso.',
        tips: <String>[
          'Mezcla opción múltiple, verdadero/falso y respuesta corta.',
          'Un fallo no es un fracaso: señala exactamente qué repasar.',
        ],
        action: StudyAction(
          label: 'Abrir Evaluaciones',
          target: StudyTarget.subjectAssessments,
        ),
      ),
      StudyStep(
        title: 'Enseña lo aprendido',
        duration: '5 min',
        description:
            'Explica el tema en 2 minutos con un ejemplo cotidiano. Si no '
            'puedes simplificarlo, todavía no lo dominas.',
        tips: <String>[
          'Técnica Feynman: simple, con ejemplo y sin jerga.',
          'Pide al asistente que te haga preguntas de seguimiento.',
        ],
        action: StudyAction(
          label: 'Explicar con el asistente',
          target: StudyTarget.assistant,
        ),
      ),
    ],
  ),
  StudyPhase(
    title: 'Fase 4 · Consolidación',
    subtitle: 'Fija el aprendizaje en la memoria a largo plazo · continuo',
    icon: Icons.event_repeat_outlined,
    steps: <StudyStep>[
      StudyStep(
        title: 'Repaso espaciado',
        duration: '5 min por repaso',
        description:
            'Recupera de memoria antes de releer. Repasa a los 10 minutos, a '
            'las 24 horas, a los 7 días y a los 30 días. Cada repaso debe ser '
            'activo, no una lectura pasiva.',
        tips: <String>[
          'Si fallas, vuelve a la explicación y programa otro repaso.',
          'El calendario debe reflejar estas cuatro fechas.',
        ],
        action: StudyAction(
          label: 'Programar en el calendario',
          target: StudyTarget.calendar,
        ),
      ),
      StudyStep(
        title: 'Descanso y sueño',
        duration: '7-9 h',
        description:
            'El sueño consolida lo aprendido. Evita pantallas 30 minutos antes '
            'de dormir y repasa mentalmente el mapa del tema.',
        tips: <String>[
          'Una siesta de 20 minutos también ayuda si es temprano.',
          'La privación de sueño reduce la retención aunque estudies más.',
        ],
        action: StudyAction(
          label: 'Volver al inicio',
          target: StudyTarget.home,
        ),
      ),
      StudyStep(
        title: 'Revisión semanal',
        duration: '20 min',
        description:
            'Revisa tu dominio por tema, identifica puntos débiles y '
            'reprograma las sesiones pendientes sin duplicar el plan.',
        tips: <String>[
          'Hazlo el mismo día cada semana.',
          'Ajusta tiempos reales, no ideales.',
        ],
        action: StudyAction(
          label: 'Revisar calendario',
          target: StudyTarget.calendar,
        ),
      ),
    ],
  ),
];

class StudyPlanScreen extends ConsumerWidget {
  const StudyPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return const EmptyState(
        icon: Icons.route_outlined,
        title: 'Plan de estudio',
        message: 'Crea un perfil para aplicar el método de estudio.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
      children: <Widget>[
        const _MethodHeader(),
        const SizedBox(height: 20),
        const _PrinciplesCard(),
        const SizedBox(height: 28),
        for (final phase in _phases) ...<Widget>[
          _PhaseHeader(phase: phase),
          const SizedBox(height: 8),
          for (var index = 0; index < phase.steps.length; index++) ...[
            _StepCard(
              step: phase.steps[index],
              number: _stepNumber(phase, index),
              onAction: () =>
                  _runAction(context, ref, phase.steps[index].action),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 20),
        ],
        const _ExpressCard(),
        const SizedBox(height: 20),
        const _GoldenRulesCard(),
      ],
    );
  }

  int _stepNumber(StudyPhase phase, int index) {
    var count = 0;
    for (final current in _phases) {
      if (current == phase) {
        return count + index + 1;
      }
      count += current.steps.length;
    }
    return index + 1;
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    StudyAction action,
  ) async {
    final tabIndex = _subjectTabIndex(action.target);
    if (tabIndex != null) {
      await _openSubjectTab(context, ref, tabIndex);
      return;
    }
    final section = _sectionIndex(action.target);
    if (section != null) {
      ref.read(navigationIndexProvider.notifier).select(section);
    }
  }

  Future<void> _openSubjectTab(
    BuildContext context,
    WidgetRef ref,
    int tabIndex,
  ) async {
    final profile = ref.read(activeProfileProvider);
    if (profile == null) {
      return;
    }
    final subjects =
        ref.read(subjectsProvider(profile.id)).asData?.value ??
        const <SubjectDto>[];
    if (subjects.isEmpty) {
      ref.read(navigationIndexProvider.notifier).select(AppSections.subjects);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Crea una asignatura para relacionar este paso con tu material.',
            ),
          ),
        );
      }
      return;
    }
    final subject = subjects.length == 1
        ? subjects.first
        : await _chooseSubject(context, subjects);
    if (subject == null || !context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SubjectSpaceScreen(subject: subject, initialTabIndex: tabIndex),
      ),
    );
  }

  Future<SubjectDto?> _chooseSubject(
    BuildContext context,
    List<SubjectDto> subjects,
  ) {
    return showDialog<SubjectDto>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('¿Con qué asignatura?'),
        children: <Widget>[
          for (final subject in subjects)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(subject),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.auto_stories_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(subject.name)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  int? _subjectTabIndex(StudyTarget target) {
    switch (target) {
      case StudyTarget.subjectFiles:
        return 1;
      case StudyTarget.subjectAssessments:
        return 4;
      case StudyTarget.subjectProgress:
        return 5;
      case StudyTarget.subjectMusic:
        return 6;
      case StudyTarget.subjectClassStart:
        return 7;
      case StudyTarget.subjects:
      case StudyTarget.home:
      case StudyTarget.calendar:
      case StudyTarget.assistant:
        return null;
    }
  }

  int? _sectionIndex(StudyTarget target) {
    switch (target) {
      case StudyTarget.subjects:
        return AppSections.subjects;
      case StudyTarget.home:
        return AppSections.home;
      case StudyTarget.calendar:
        return AppSections.calendar;
      case StudyTarget.assistant:
        return AppSections.assistant;
      case StudyTarget.subjectFiles:
      case StudyTarget.subjectMusic:
      case StudyTarget.subjectProgress:
      case StudyTarget.subjectAssessments:
      case StudyTarget.subjectClassStart:
        return null;
    }
  }
}

class _MethodHeader extends StatelessWidget {
  const _MethodHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            theme.colorScheme.primary,
            theme.colorScheme.tertiary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_stories, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Plan de estudio · Superlearning',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Una adaptación práctica de la sugestopedia de Georgi Lozanov. '
            'Combina relajación alerta, música, sugerencias positivas, '
            'aprendizaje multisensorial y repaso espaciado para retener más '
            'con menos esfuerzo.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              _HeaderChip(icon: Icons.timer_outlined, label: 'Sesión: ~90 min'),
              _HeaderChip(
                icon: Icons.event_repeat_outlined,
                label: 'Repaso: 10 min · 24 h · 7 d · 30 d',
              ),
              _HeaderChip(icon: Icons.block_outlined, label: '100 % offline'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinciplesCard extends StatelessWidget {
  const _PrinciplesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const principles = <String>[
      'Relajación alerta: cuerpo tranquilo, mente despierta.',
      'Música barroca a ~60 ppm para marcar el ritmo de entrada.',
      'Sugerencia positiva: lo que crees sobre tu capacidad afecta al resultado.',
      'Multisensorial: leer, escuchar, escribir, dibujar y explicar.',
      'Recuperación activa y repaso espaciado, no relectura pasiva.',
      'Pausas, movimiento y sueño como parte del aprendizaje.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Principios que aplica el método',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final principle in principles)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(principle, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({required this.phase});

  final StudyPhase phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 20,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            phase.icon,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                phase.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                phase.subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.number,
    required this.onAction,
  });

  final StudyStep step;
  final int number;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    step.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    step.duration,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              step.description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            if (step.tips.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              for (final tip in step.tips)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.lightbulb_outline,
                          size: 15,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          tip,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: onAction,
                icon: Icon(step.action.target.icon, size: 18),
                label: Text(step.action.label),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpressCard extends StatelessWidget {
  const _ExpressCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.bolt_outlined,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sesión exprés de 30 minutos',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Para días con poco tiempo: 2 min objetivo · 3 min macrolectura · '
              '12 min lectura activa · 5 min mapa mental · 5 min autoevaluación · '
              '3 min programar el repaso.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Lo que no se puede saltar: recuperar de memoria, autoevaluarte y '
              'programar el siguiente repaso.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoldenRulesCard extends StatelessWidget {
  const _GoldenRulesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const rules = <String>[
      'Poco y frecuente supera a mucho y de golpe.',
      'Recuperar de memoria supera a releer.',
      'Explicar supera a subrayar.',
      'Las pausas y el sueño forman parte del método, no son tiempo perdido.',
      'Mide el dominio y la retención, no solo las horas sentado.',
      'Si no puedes explicarlo con un ejemplo, vuelve al paso de lectura activa.',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Reglas de oro',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final rule in rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '•',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(rule, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
