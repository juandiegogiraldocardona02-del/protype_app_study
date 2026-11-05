import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';
import 'subject_space_screen.dart';

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final subjectsAsync = ref.watch(subjectsProvider(profile.id));

    Future<void> addSubject() async {
      final result = await showSubjectDialog(context);
      if (result == null) {
        return;
      }
      try {
        await ref
            .read(subjectActionsProvider)
            .create(profile.id, result.name, result.color);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('No se pudo crear: $error')));
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'No se pudieron cargar las asignaturas',
          message: error.toString(),
        ),
        data: (subjects) {
          if (subjects.isEmpty) {
            return EmptyState(
              icon: Icons.library_books_outlined,
              title: 'Sin asignaturas todavía',
              message:
                  'Crea una asignatura para empezar a organizar su agenda, '
                  'documentos, tareas y evaluaciones.',
              action: FilledButton.icon(
                onPressed: addSubject,
                icon: const Icon(Icons.add),
                label: const Text('Crear asignatura'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
            itemCount: subjects.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final subject = subjects[index];
              return Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: colorFromHex(subject.color),
                    child: const Icon(Icons.book_outlined, color: Colors.white),
                  ),
                  title: Text(subject.name),
                  subtitle: const Text('Agenda · Archivos · Tareas · Progreso'),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Opciones de ${subject.name}',
                    onSelected: (value) async {
                      if (value == 'edit') {
                        final result = await showSubjectDialog(
                          context,
                          initialName: subject.name,
                          initialColor: subject.color,
                          title: 'Editar asignatura',
                        );
                        if (result == null || !context.mounted) {
                          return;
                        }
                        await ref
                            .read(subjectActionsProvider)
                            .update(
                              profile.id,
                              subject.id,
                              result.name,
                              result.color,
                            );
                      } else if (value == 'delete') {
                        final confirmed = await showConfirmDialog(
                          context,
                          title: 'Eliminar asignatura',
                          message:
                              '¿Eliminar «${subject.name}» y todos sus datos? '
                              'Esta acción no se puede deshacer.',
                          confirmLabel: 'Eliminar',
                        );
                        if (!confirmed || !context.mounted) {
                          return;
                        }
                        await ref
                            .read(subjectActionsProvider)
                            .delete(profile.id, subject.id);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Eliminar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SubjectSpaceScreen(subject: subject),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: addSubject,
        icon: const Icon(Icons.add),
        label: const Text('Asignatura'),
      ),
    );
  }
}
