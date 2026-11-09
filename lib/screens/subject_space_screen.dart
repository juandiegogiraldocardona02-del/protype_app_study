import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/bridge.dart';
import '../state/providers.dart';
import '../widgets/dialogs.dart';
import '../widgets/document_library.dart';
import '../widgets/empty_state.dart';
import '../widgets/subject_agenda.dart';
import '../widgets/subject_assessments.dart';
import '../widgets/subject_progress.dart';
import '../widgets/subject_class_start.dart';
import '../widgets/subject_music.dart';

class SubjectSpaceScreen extends ConsumerWidget {
  const SubjectSpaceScreen({super.key, required this.subject});

  final SubjectDto subject;

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final directory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Elegir carpeta para exportar la asignatura',
    );
    if (directory == null || !context.mounted) {
      return;
    }
    try {
      final result = await ref
          .read(backupActionsProvider)
          .exportStudyPlan(subject.id, directory);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.message} Archivo: ${result.path}')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo exportar: $error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorFromHex(subject.color);
    return DefaultTabController(
      length: 8,
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
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Acciones de la asignatura',
              onSelected: (value) {
                if (value == 'export') {
                  _export(context, ref);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.save_alt_outlined),
                    title: Text('Exportar .studyplan'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
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
              Tab(icon: Icon(Icons.music_note_outlined), text: 'Música'),
              Tab(icon: Icon(Icons.school_outlined), text: 'Inicio de clase'),
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
            SubjectAssessmentsPanel(subject: subject),
            SubjectProgressPanel(subject: subject),
            SubjectMusicPanel(subject: subject),
            SubjectClassStartPanel(subject: subject),
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
