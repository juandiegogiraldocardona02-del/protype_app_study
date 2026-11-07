import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart';
import '../widgets/empty_state.dart';
import 'subject_space_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final subjectsAsync = ref.watch(subjectsProvider(profile.id));
    final gamification = ref.watch(gamificationProvider(profile.id));

    return subjectsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorView(message: error.toString()),
      data: (subjects) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Hola, ${profile.name}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Tu planificación vive en este dispositivo. Sin cuentas, sin nube.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _SummaryRow(
              subjectCount: subjects.length,
              profileName: profile.name,
            ),
            const SizedBox(height: 16),
            gamification.when(
              loading: () => const SizedBox.shrink(),
              error: (error, _) => const SizedBox.shrink(),
              data: (summary) => _GamificationCard(summary: summary),
            ),
            const SizedBox(height: 28),
            if (subjects.isEmpty)
              EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'Empieza creando una asignatura',
                message:
                    'Cada asignatura tendrá su propio espacio con agenda, '
                    'archivos, tareas, calendario, evaluaciones y progreso.',
                action: FilledButton.icon(
                  onPressed: () =>
                      ref.read(navigationIndexProvider.notifier).select(1),
                  icon: const Icon(Icons.add),
                  label: const Text('Ir a Mis materias'),
                ),
              )
            else ...[
              Row(
                children: [
                  Text(
                    'Tus asignaturas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () =>
                        ref.read(navigationIndexProvider.notifier).select(1),
                    child: const Text('Ver todas'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final subject in subjects)
                    SizedBox(
                      width: 260,
                      child: Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _subjectColor(subject.color),
                            child: const Icon(
                              Icons.book_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          title: Text(subject.name),
                          subtitle: const Text('Abrir espacio'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  SubjectSpaceScreen(subject: subject),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            const _ComingSoonCard(),
          ],
        );
      },
    );
  }
}

Color _subjectColor(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16) ?? 0x4F46E5;
  return Color(0xFF000000 | value);
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.subjectCount, required this.profileName});

  final int subjectCount;
  final String profileName;

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, String value})>[
      (
        icon: Icons.menu_book_outlined,
        label: 'Asignaturas',
        value: '$subjectCount',
      ),
      (icon: Icons.person_outline, label: 'Perfil activo', value: profileName),
      (icon: Icons.wifi_off, label: 'Modo', value: '100 % offline'),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items)
          SizedBox(
            width: 220,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(item.icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.label,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            item.value,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GamificationCard extends StatelessWidget {
  const _GamificationCard({required this.summary});

  final GamificationSummaryDto summary;

  @override
  Widget build(BuildContext context) {
    final progress = summary.xpForNextLevel <= 0
        ? 0.0
        : summary.xpInLevel / summary.xpForNextLevel;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(radius: 26, child: Text('${summary.level}')),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nivel ${summary.level} · ${summary.totalXp} XP',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text('Racha ${summary.currentStreak} d'),
                      const Spacer(),
                      Text('Mejor ${summary.bestStreak} d'),
                    ],
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

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.schedule, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'El asistente local y las evaluaciones automáticas se '
                'activarán en las siguientes etapas del plan.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: 'No se pudieron cargar los datos',
      message: message,
    );
  }
}
