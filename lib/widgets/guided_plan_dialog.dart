import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart';

typedef GuidedPlanChoice = ({int subjectId, List<PlannedSessionDto> sessions});

const List<({String level, String title, String subtitle, IconData icon})>
_levels = [
  (
    level: 'medio',
    title: 'Medio',
    subtitle: 'Repaso ligero para empezar sin sobrecarga.',
    icon: Icons.spa_outlined,
  ),
  (
    level: 'intermedio',
    title: 'Intermedio',
    subtitle: 'Equilibrio recomendado entre temas y tiempo.',
    icon: Icons.balance_outlined,
  ),
  (
    level: 'intenso',
    title: 'Intenso',
    subtitle: 'Cobertura completa para dominar la guía.',
    icon: Icons.local_fire_department_outlined,
  ),
];

Future<GuidedPlanChoice?> showGuidedPlanDialog(
  BuildContext context, {
  required List<SubjectDto> subjects,
  required int initialSubjectId,
}) {
  return showDialog<GuidedPlanChoice>(
    context: context,
    builder: (context) => _GuidedPlanDialog(
      subjects: subjects,
      initialSubjectId: initialSubjectId,
    ),
  );
}

class _GuidedPlanDialog extends ConsumerStatefulWidget {
  const _GuidedPlanDialog({
    required this.subjects,
    required this.initialSubjectId,
  });

  final List<SubjectDto> subjects;
  final int initialSubjectId;

  @override
  ConsumerState<_GuidedPlanDialog> createState() => _GuidedPlanDialogState();
}

class _GuidedPlanDialogState extends ConsumerState<_GuidedPlanDialog> {
  late int _subjectId;
  bool _includeToday = true;
  int _selectedLevel = 1;
  int _loadToken = 0;
  final Map<String, AsyncValue<GuidedPlanDto>> _previews = {};

  @override
  void initState() {
    super.initState();
    _subjectId = widget.initialSubjectId;
    _load();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() {
      for (final level in _levels) {
        _previews[level.level] = const AsyncLoading();
      }
    });
    for (final level in _levels) {
      try {
        final proposal = await ref
            .read(planActionsProvider)
            .previewGuided(_subjectId, level.level, _includeToday);
        if (!mounted || token != _loadToken) {
          return;
        }
        setState(() => _previews[level.level] = AsyncData(proposal));
      } catch (error, stack) {
        if (!mounted || token != _loadToken) {
          return;
        }
        setState(() => _previews[level.level] = AsyncError(error, stack));
      }
    }
  }

  Future<void> _save() async {
    final level = _levels[_selectedLevel];
    final preview = _previews[level.level];
    final proposal = preview?.asData?.value;
    if (proposal == null || proposal.sessions.isEmpty) {
      return;
    }
    Navigator.of(context)
        .pop((subjectId: _subjectId, sessions: proposal.sessions));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _levels[_selectedLevel];
    final selectedPreview = _previews[selected.level];
    final canSave = selectedPreview?.asData?.value.sessions.isNotEmpty ?? false;

    return AlertDialog(
      title: const Text('Generar plan recomendado'),
      content: SizedBox(
        width: 640,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Elige la materia y la intensidad. La IA local tomará los puntos '
              'de la guía y repartirá temas y tiempo en secciones.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _subjectId,
              decoration: const InputDecoration(
                labelText: 'Materia',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final subject in widget.subjects)
                  DropdownMenuItem<int>(
                    value: subject.id,
                    child: Text(subject.name),
                  ),
              ],
              onChanged: (value) {
                if (value == null || value == _subjectId) {
                  return;
                }
                setState(() => _subjectId = value);
                _load();
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _includeToday,
              onChanged: (value) {
                setState(() => _includeToday = value);
                _load();
              },
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir hoy'),
              subtitle: const Text(
                'Permite crear el plan para el mismo día, aunque hoy no esté '
                'en tu disponibilidad habitual.',
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  for (var index = 0; index < _levels.length; index++)
                    _LevelCard(
                      level: _levels[index],
                      selected: index == _selectedLevel,
                      preview: _previews[_levels[index].level],
                      onTap: () => setState(() => _selectedLevel = index),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: canSave ? _save : null,
          icon: const Icon(Icons.event_available_outlined),
          label: const Text('Guardar en Tareas'),
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final ({String level, String title, String subtitle, IconData icon}) level;
  final bool selected;
  final AsyncValue<GuidedPlanDto>? preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final proposal = preview?.asData?.value;
    final error = preview?.error;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                level.icon,
                color: selected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            level.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (level.level == 'intermedio')
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Recomendado',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        if (selected)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check_circle,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(level.subtitle, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    if (preview?.isLoading ?? false)
                      const LinearProgressIndicator(minHeight: 3)
                    else if (error != null)
                      Text(
                        _describe(error),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.error,
                        ),
                      )
                    else if (proposal != null)
                      Text(
                        '${proposal.topicsCount} temas · '
                        '${proposal.stepsCount} pasos · '
                        '${(proposal.totalMinutes / 60).toStringAsFixed(1)} h · '
                        'termina ${proposal.lastDate}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

String _describe(Object error) {
  final text = error.toString();
  const prefixes = <String>['AnyhowException(', 'Exception: ', 'Error: '];
  var value = text;
  var changed = true;
  while (changed) {
    changed = false;
    for (final prefix in prefixes) {
      if (value.startsWith(prefix)) {
        value = value.substring(prefix.length);
        changed = true;
      }
    }
  }
  if (value.endsWith(')')) {
    value = value.substring(0, value.length - 1);
  }
  return value.trim();
}
