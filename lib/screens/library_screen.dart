import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_sections.dart';
import '../state/providers.dart';
import '../widgets/document_library.dart';
import '../widgets/empty_state.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int? _selectedSubjectId;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return const EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'Biblioteca',
        message: 'Crea un perfil para organizar tus documentos por asignatura.',
      );
    }

    final subjects = ref.watch(subjectsProvider(profile.id));
    return subjects.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'No se pudieron cargar las asignaturas',
        message: '$error',
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.folder_open_outlined,
            title: 'Sin asignaturas',
            message:
                'La biblioteca se organiza por asignatura. Crea una para '
                'empezar a importar documentos.',
            action: FilledButton.icon(
              onPressed: () => ref
                  .read(navigationIndexProvider.notifier)
                  .select(AppSections.subjects),
              icon: const Icon(Icons.add),
              label: const Text('Ir a Mis materias'),
            ),
          );
        }

        final selected = items.any((item) => item.id == _selectedSubjectId)
            ? _selectedSubjectId!
            : items.first.id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Asignatura',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: selected,
                    onChanged: (value) =>
                        setState(() => _selectedSubjectId = value),
                    items: [
                      for (final subject in items)
                        DropdownMenuItem<int>(
                          value: subject.id,
                          child: Text(subject.name),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: DocumentLibrary(
                key: ValueKey<int>(selected),
                subjectId: selected,
              ),
            ),
          ],
        );
      },
    );
  }
}
