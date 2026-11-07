import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart';
import 'dialogs.dart';

const Map<int, String> _weekdayLabels = <int, String>{
  1: 'L',
  2: 'M',
  3: 'X',
  4: 'J',
  5: 'V',
  6: 'S',
  7: 'D',
};

class SubjectAgendaPanel extends ConsumerWidget {
  const SubjectAgendaPanel({super.key, required this.subject});

  final SubjectDto subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider(subject.id));
    final settings = ref.watch(planSettingsProvider(subject.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text('Temas', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _addTopic(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Añadir tema'),
            ),
          ],
        ),
        topics.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('No se pudieron cargar los temas: $error'),
          data: (items) {
            if (items.isEmpty) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.list_alt_outlined),
                  title: const Text('Aún no hay temas'),
                  subtitle: const Text(
                    'Añade los temas de la asignatura para que el planificador '
                    'pueda repartirlos en sesiones.',
                  ),
                  trailing: FilledButton(
                    onPressed: () => _addTopic(context, ref),
                    child: const Text('Añadir'),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final topic in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(topic.difficulty.round().toString()),
                      ),
                      title: Text(topic.name),
                      subtitle: Text(
                        'Dificultad ${topic.difficulty.round()}/5 · '
                        'dominio ${(topic.mastery * 100).round()}%',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar tema',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editTopic(context, ref, topic),
                          ),
                          IconButton(
                            tooltip: 'Eliminar tema',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteTopic(context, ref, topic),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        settings.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('No se pudo cargar el plan: $error'),
          data: (value) => _PlanCard(
            settings: value,
            onConfigure: () => _configure(context, ref, value),
            onGenerate: () => _generate(context, ref),
            onReplan: () => _replan(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _addTopic(BuildContext context, WidgetRef ref) async {
    final result = await showTopicDialog(context);
    if (result == null) {
      return;
    }
    try {
      await ref
          .read(topicActionsProvider)
          .create(subject.id, result.name, result.difficulty);
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _editTopic(
    BuildContext context,
    WidgetRef ref,
    TopicDto topic,
  ) async {
    final result = await showTopicDialog(
      context,
      title: 'Editar tema',
      initialName: topic.name,
      initialDifficulty: topic.difficulty,
    );
    if (result == null) {
      return;
    }
    try {
      await ref
          .read(topicActionsProvider)
          .update(subject.id, topic.id, result.name, result.difficulty);
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _deleteTopic(
    BuildContext context,
    WidgetRef ref,
    TopicDto topic,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar tema',
      message:
          '¿Eliminar «${topic.name}»? Las sesiones ya planificadas se '
          'conservarán sin tema asociado.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(topicActionsProvider).delete(subject.id, topic.id);
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _configure(
    BuildContext context,
    WidgetRef ref,
    PlanSettingsDto settings,
  ) async {
    final saved = await _showPlanSettingsDialog(context, settings);
    if (saved == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(planActionsProvider)
          .saveSettings(
            subject.id,
            saved.sessionMinutes,
            saved.startHour,
            saved.deadline,
            saved.availability,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disponibilidad guardada.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    try {
      final proposal = await ref.read(planActionsProvider).preview(subject.id);
      if (!context.mounted) {
        return;
      }
      final chosen = await _showPlanPreviewDialog(context, proposal);
      if (chosen == null || chosen.isEmpty || !context.mounted) {
        return;
      }
      final count = await ref
          .read(planActionsProvider)
          .save(subject.id, chosen);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Plan guardado con $count sesiones.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _replan(BuildContext context, WidgetRef ref) async {
    try {
      final result = await ref.read(planActionsProvider).replan(subject.id);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () async {
              try {
                final reverted = await ref
                    .read(planActionsProvider)
                    .revert(subject.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Replanificación revertida ($reverted sesiones).',
                      ),
                    ),
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  _showError(context, error);
                }
              }
            },
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_describe(error))));
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.settings,
    required this.onConfigure,
    required this.onGenerate,
    required this.onReplan,
  });

  final PlanSettingsDto settings;
  final VoidCallback onConfigure;
  final VoidCallback onGenerate;
  final VoidCallback onReplan;

  @override
  Widget build(BuildContext context) {
    final weeklyMinutes = settings.availability.fold<int>(
      0,
      (total, day) => total + day.minutes,
    );
    final days = settings.availability
        .map((day) => _weekdayLabels[day.weekday] ?? '?')
        .join(' ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Planificación de la asignatura',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: onConfigure,
                  child: const Text('Configurar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sesiones de ${settings.sessionMinutes} min · '
              '${(weeklyMinutes / 60).toStringAsFixed(1)} h/semana',
            ),
            Text('Días: ${days.isEmpty ? 'sin configurar' : days}'),
            Text('Fecha límite: ${settings.deadline}'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onGenerate,
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Generar plan'),
                ),
                OutlinedButton.icon(
                  onPressed: onReplan,
                  icon: const Icon(Icons.autorenew),
                  label: const Text('Replanificar pendientes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

typedef _SettingsResult = ({
  int sessionMinutes,
  int startHour,
  String deadline,
  List<AvailabilityDayDto> availability,
});

Future<_SettingsResult?> _showPlanSettingsDialog(
  BuildContext context,
  PlanSettingsDto settings,
) {
  var sessionMinutes = settings.sessionMinutes;
  var startHour = settings.startHour;
  var deadline = settings.deadline;
  final selectedDays = <int>{
    for (final day in settings.availability) day.weekday,
  };
  var minutesPerDay = settings.availability.isEmpty
      ? 120
      : settings.availability.first.minutes;

  return showDialog<_SettingsResult>(
    context: context,
    builder: (context) {
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickDeadline() async {
            final today = DateTime.now();
            final initial =
                DateTime.tryParse(deadline) ??
                today.add(const Duration(days: 30));
            final picked = await showDatePicker(
              context: context,
              initialDate: initial.isBefore(today) ? today : initial,
              firstDate: today,
              lastDate: today.add(const Duration(days: 365 * 3)),
            );
            if (picked != null) {
              setState(() {
                deadline =
                    '${picked.year.toString().padLeft(4, '0')}-'
                    '${picked.month.toString().padLeft(2, '0')}-'
                    '${picked.day.toString().padLeft(2, '0')}';
              });
            }
          }

          void save() {
            if (selectedDays.isEmpty) {
              setState(() => errorText = 'Selecciona al menos un día');
              return;
            }
            Navigator.of(context).pop((
              sessionMinutes: sessionMinutes,
              startHour: startHour,
              deadline: deadline,
              availability: [
                for (final day in selectedDays)
                  AvailabilityDayDto(weekday: day, minutes: minutesPerDay),
              ]..sort((a, b) => a.weekday.compareTo(b.weekday)),
            ));
          }

          return AlertDialog(
            title: const Text('Disponibilidad semanal'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: sessionMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Duración de cada sesión',
                      ),
                      items: const [30, 45, 50, 60, 90, 120]
                          .map(
                            (minutes) => DropdownMenuItem<int>(
                              value: minutes,
                              child: Text('$minutes min'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => sessionMinutes = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Días disponibles',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final entry in _weekdayLabels.entries)
                          FilterChip(
                            label: Text(entry.value),
                            selected: selectedDays.contains(entry.key),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                selectedDays.add(entry.key);
                              } else {
                                selectedDays.remove(entry.key);
                              }
                              errorText = null;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: minutesPerDay,
                      decoration: const InputDecoration(
                        labelText: 'Minutos disponibles por día',
                      ),
                      items: const [30, 60, 90, 120, 180, 240, 300, 360]
                          .map(
                            (minutes) => DropdownMenuItem<int>(
                              value: minutes,
                              child: Text('$minutes min'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => minutesPerDay = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: startHour,
                      decoration: const InputDecoration(
                        labelText: 'Hora de inicio',
                      ),
                      items: [
                        for (var hour = 6; hour <= 22; hour++)
                          DropdownMenuItem<int>(
                            value: hour,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                            ),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => startHour = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: Text('Fecha límite: $deadline')),
                        TextButton.icon(
                          onPressed: pickDeadline,
                          icon: const Icon(Icons.event_outlined),
                          label: const Text('Cambiar'),
                        ),
                      ],
                    ),
                    if (errorText != null)
                      Text(
                        errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(onPressed: save, child: const Text('Guardar')),
            ],
          );
        },
      );
    },
  );
}

Future<List<PlannedSessionDto>?> _showPlanPreviewDialog(
  BuildContext context,
  PlanProposalDto proposal,
) {
  return showDialog<List<PlannedSessionDto>>(
    context: context,
    builder: (context) => _PlanPreviewDialog(proposal: proposal),
  );
}

class _PlanPreviewDialog extends StatefulWidget {
  const _PlanPreviewDialog({required this.proposal});

  final PlanProposalDto proposal;

  @override
  State<_PlanPreviewDialog> createState() => _PlanPreviewDialogState();
}

class _PlanPreviewDialogState extends State<_PlanPreviewDialog> {
  late final List<bool> _included = List<bool>.filled(
    widget.proposal.sessions.length,
    true,
  );

  @override
  Widget build(BuildContext context) {
    final included = <PlannedSessionDto>[
      for (var i = 0; i < _included.length; i++)
        if (_included[i]) widget.proposal.sessions[i],
    ];
    final minutes = included.fold<int>(
      0,
      (total, session) => total + session.durationMin,
    );
    return AlertDialog(
      title: const Text('Vista previa del plan'),
      content: SizedBox(
        width: 560,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${included.length} sesiones · ${(minutes / 60).toStringAsFixed(1)} h '
              '· termina el ${widget.proposal.lastDate}',
            ),
            Text(
              'Disponibilidad: '
              '${(widget.proposal.weeklyMinutes / 60).toStringAsFixed(1)} h/semana',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Desmarca las sesiones que no quieras incluir.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: widget.proposal.sessions.length,
                itemBuilder: (context, index) {
                  final session = widget.proposal.sessions[index];
                  return CheckboxListTile(
                    dense: true,
                    value: _included[index],
                    onChanged: (value) =>
                        setState(() => _included[index] = value ?? false),
                    title: Text(session.topicName),
                    subtitle: Text(
                      '${_formatStart(session.start)} · '
                      '${session.durationMin} min',
                    ),
                  );
                },
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
        FilledButton(
          onPressed: included.isEmpty
              ? null
              : () => Navigator.of(context).pop(included),
          child: Text('Guardar plan (${included.length})'),
        ),
      ],
    );
  }
}

String _formatStart(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return iso;
  }
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(parsed.day)}/${two(parsed.month)} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
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
