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
import '../widgets/subject_class_start.dart';
import '../widgets/subject_music.dart';
import '../widgets/subject_pdfs.dart';
import '../widgets/subject_progress.dart';

class SubjectSpaceScreen extends ConsumerWidget {
  const SubjectSpaceScreen({
    super.key,
    required this.subject,
    this.initialTabIndex,
  });

  final SubjectDto subject;
  final int? initialTabIndex;

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
        SnackBar(
          content: Text('${result.message} Archivo: ${result.path}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo exportar: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = colorFromHex(subject.color);
    return DefaultTabController(
      length: 9,
      initialIndex: initialTabIndex ?? 0,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
                child: Text(
                  subject.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
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
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                border: Border(
                  bottom: BorderSide(
                    color: color.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.book_outlined, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Espacio de la asignatura',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
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
                  SubjectClassStartPanel(subjectId: subject.id),
                  SubjectPdfsPanel(subjectId: subject.id),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: TabBar(
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          tabs: [
            Tab(icon: Icon(Icons.event_note_outlined), text: 'Agenda'),
            Tab(icon: Icon(Icons.folder_outlined), text: 'Archivos'),
            Tab(icon: Icon(Icons.checklist_outlined), text: 'Tareas'),
            Tab(icon: Icon(Icons.calendar_month_outlined), text: 'Calendario'),
            Tab(icon: Icon(Icons.quiz_outlined), text: 'Evaluaciones'),
            Tab(icon: Icon(Icons.insights_outlined), text: 'Progreso'),
            Tab(icon: Icon(Icons.music_note_outlined), text: 'Música'),
            Tab(icon: Icon(Icons.school_outlined), text: 'Inicio de clase'),
            Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'PDFs'),
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
