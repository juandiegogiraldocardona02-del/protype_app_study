import 'package:flutter/material.dart';

import '../bridge/bridge.dart';
import '../widgets/dialogs.dart';
import '../widgets/document_library.dart';
import '../widgets/empty_state.dart';
import '../widgets/subject_agenda.dart';
import '../widgets/subject_progress.dart';

class SubjectSpaceScreen extends StatelessWidget {
  const SubjectSpaceScreen({super.key, required this.subject});

  final SubjectDto subject;

  @override
  Widget build(BuildContext context) {
    final color = colorFromHex(subject.color);
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: color,
                child: const Icon(
                  Icons.book_outlined,
                  size: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(subject.name, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.event_note_outlined), text: 'Agenda'),
              Tab(icon: Icon(Icons.folder_outlined), text: 'Archivos'),
              Tab(icon: Icon(Icons.checklist_outlined), text: 'Tareas'),
              Tab(
                icon: Icon(Icons.calendar_month_outlined),
                text: 'Calendario',
              ),
              Tab(icon: Icon(Icons.quiz_outlined), text: 'Evaluaciones'),
              Tab(icon: Icon(Icons.insights_outlined), text: 'Progreso'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SubjectAgendaPanel(subject: subject),
            DocumentLibrary(subjectId: subject.id),
            const _StagePanel(
              icon: Icons.checklist_outlined,
              title: 'Tareas',
              message:
                  'Las tareas vinculadas al calendario se habilitarán junto con '
                  'la planificación (etapa E3).',
            ),
            const _StagePanel(
              icon: Icons.calendar_month_outlined,
              title: 'Calendario propio',
              message:
                  'Vistas mensual, semanal y diaria con filtros por asignatura '
                  'en la etapa E3.',
            ),
            const _StagePanel(
              icon: Icons.quiz_outlined,
              title: 'Evaluaciones',
              message:
                  'Los cuestionarios generados desde tus documentos llegarán en '
                  'la etapa E8, con corrección totalmente local.',
            ),
            SubjectProgressPanel(subject: subject),
          ],
        ),
      ),
    );
  }
}

class _StagePanel extends StatelessWidget {
  const _StagePanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(icon: icon, title: title, message: message);
  }
}
