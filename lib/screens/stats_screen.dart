import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart';
import '../widgets/empty_state.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final summary = ref.watch(gamificationProvider(profile.id));

    return summary.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'No se pudieron cargar las estadísticas',
        message: error.toString(),
      ),
      data: (value) {
        final progress = value.xpForNextLevel <= 0
            ? 0.0
            : value.xpInLevel / value.xpForNextLevel;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Progreso de ${profile.name}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(
                  icon: Icons.stars_outlined,
                  label: 'Nivel',
                  value: '${value.level}',
                ),
                _StatCard(
                  icon: Icons.bolt_outlined,
                  label: 'XP total',
                  value: '${value.totalXp}',
                ),
                _StatCard(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Racha actual',
                  value: '${value.currentStreak} d',
                ),
                _StatCard(
                  icon: Icons.emoji_events_outlined,
                  label: 'Mejor racha',
                  value: '${value.bestStreak} d',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nivel ${value.level}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${value.xpInLevel} / ${value.xpForNextLevel} XP para el '
                      'siguiente nivel',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Insignias', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final badge in value.badges) _BadgeTile(badge: badge),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('XP por actividad'),
                subtitle: const Text(
                  'Configura cuánto XP otorga cada actividad desde la pestaña '
                  'Progreso de cada asignatura. Los cambios solo afectan a '
                  'actividades futuras.',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelMedium),
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final BadgeDto badge;

  @override
  Widget build(BuildContext context) {
    final color = badge.earned
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).disabledColor;
    return SizedBox(
      width: 260,
      child: Card(
        child: ListTile(
          leading: Icon(
            badge.earned ? Icons.emoji_events : Icons.lock_outline,
            color: color,
          ),
          title: Text(badge.title),
          subtitle: Text(badge.description),
          enabled: badge.earned,
        ),
      ),
    );
  }
}
