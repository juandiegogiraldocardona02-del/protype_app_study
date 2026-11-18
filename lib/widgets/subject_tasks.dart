import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart' show SessionDto;
import 'empty_state.dart';

class SubjectTasksPanel extends ConsumerStatefulWidget {
  const SubjectTasksPanel({super.key, required this.subjectId});

  final int subjectId;

  @override
  ConsumerState<SubjectTasksPanel> createState() => _SubjectTasksPanelState();
}

class _SubjectTasksPanelState extends ConsumerState<SubjectTasksPanel> {
  int? _selectedSessionId;
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectSession(SessionDto session) {
    if (_isRunning) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pausa la sesión actual antes de cambiar de tarea.'),
        ),
      );
      return;
    }
    _timer?.cancel();
    final base = session.studiedSeconds;
    var elapsed = base;
    if (session.startedAt != null) {
      final started = DateTime.tryParse(session.startedAt!);
      if (started != null) {
        final delta = DateTime.now().difference(started).inSeconds;
        if (delta > 0) {
          elapsed += delta;
        }
      }
    }
    final total = session.durationMin * 60;
    setState(() {
      _selectedSessionId = session.id;
      _elapsedSeconds = elapsed.clamp(0, total).toInt();
      _isRunning = session.startedAt != null;
    });
    if (_isRunning) {
      _runTimer();
    }
  }

  void _runTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRunning) {
        return;
      }
      final session = _selectedSession();
      if (session == null) {
        _timer?.cancel();
        return;
      }
      final total = session.durationMin * 60;
      setState(() {
        _elapsedSeconds = (_elapsedSeconds + 1).clamp(0, total).toInt();
      });
      if (_elapsedSeconds >= total) {
        _timer?.cancel();
        unawaited(_complete(session));
      }
    });
  }

  Future<void> _start() async {
    final session = _selectedSession();
    if (session == null || _isRunning) {
      return;
    }
    try {
      await ref.read(planActionsProvider).startSession(session.id);
      if (!mounted) {
        return;
      }
      setState(() => _isRunning = true);
      _runTimer();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _pause() async {
    final session = _selectedSession();
    if (session == null) {
      return;
    }
    _timer?.cancel();
    setState(() => _isRunning = false);
    try {
      await ref
          .read(planActionsProvider)
          .pauseSession(session.id, _elapsedSeconds);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Progreso guardado: ${_formatTime(_elapsedSeconds)} de estudio.',
          ),
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _complete(SessionDto session) async {
    _timer?.cancel();
    setState(() => _isRunning = false);
    try {
      final studied = session.durationMin * 60;
      await ref.read(planActionsProvider).completeSession(session.id, studied);
      if (!mounted) {
        return;
      }
      unawaited(SystemSound.play(SystemSoundType.alert));
      setState(() {
        _selectedSessionId = null;
        _elapsedSeconds = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tarea completada. ¡XP otorgado!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _finishEarly(SessionDto session) async {
    if (_elapsedSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aún no hay tiempo estudiado que descontar.'),
        ),
      );
      return;
    }
    _timer?.cancel();
    setState(() => _isRunning = false);
    try {
      final remaining = await ref
          .read(planActionsProvider)
          .finishSessionEarly(session.id, _elapsedSeconds);
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedSessionId = null;
        _elapsedSeconds = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            remaining == 0
                ? 'Tiempo descontado. ¡Tarea completada!'
                : 'Tiempo descontado. Quedan $remaining min para completar.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      _showError(error);
    }
  }

  SessionDto? _selectedSession() {
    final id = _selectedSessionId;
    if (id == null) {
      return null;
    }
    final profile = ref.read(activeProfileProvider);
    if (profile == null) {
      return null;
    }
    final sessions = ref
        .read(sessionsProvider(_query(profile.id)))
        .asData
        ?.value;
    if (sessions == null) {
      return null;
    }
    for (final session in sessions) {
      if (session.id == id) {
        return session;
      }
    }
    return null;
  }

  SessionQuery _query(int profileId) {
    final now = DateTime.now();
    return SessionQuery(
      profileId: profileId,
      subjectId: widget.subjectId,
      start: _isoDate(now.subtract(const Duration(days: 365))),
      end: _isoDate(now.add(const Duration(days: 730))),
    );
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo actualizar la tarea: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return const EmptyState(
        icon: Icons.checklist_outlined,
        title: 'Tareas',
        message: 'Crea un perfil para comenzar a organizar tus tareas.',
      );
    }
    final sessionsAsync = ref.watch(sessionsProvider(_query(profile.id)));

    return sessionsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'No se pudieron cargar las tareas',
        message: error.toString(),
      ),
      data: (sessions) {
        if (sessions.isEmpty) {
          return const EmptyState(
            icon: Icons.checklist_outlined,
            title: 'Sin tareas todavía',
            message:
                'Genera un plan desde Agenda o desde Plan de estudio para ver '
                'aquí tus secciones con cronómetro y tiempo restante.',
          );
        }
        final selected = _selectedSessionId == null
            ? null
            : sessions
                  .where((session) => session.id == _selectedSessionId)
                  .firstOrNull;
        final pending = sessions
            .where((session) => session.state != 'completada')
            .length;
        final completed = sessions.length - pending;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Tareas y plan de estudio',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '$pending pendientes · $completed completadas. Inicia cada '
              'sección para guardar tu tiempo de estudio.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final session in sessions) ...[
              _TaskCard(
                session: session,
                selected: session.id == _selectedSessionId,
                onTap: session.state == 'completada'
                    ? null
                    : () => _selectSession(session),
              ),
              if (selected != null && session.id == selected.id)
                _TaskTimerCard(
                  session: selected,
                  elapsedSeconds: _elapsedSeconds,
                  isRunning: _isRunning,
                  formatTime: _formatTime,
                  onStart: _start,
                  onPause: _pause,
                  onComplete: () => _complete(selected),
                  onFinishEarly: () => _finishEarly(selected),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final SessionDto session;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = session.state == 'completada';
    final inProgress = session.startedAt != null;
    final total = session.durationMin * 60;
    final studied = session.studiedSeconds;
    final progress = total == 0
        ? 0.0
        : (studied / total).clamp(0.0, 1.0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: completed
              ? theme.colorScheme.primary
              : theme.colorScheme.primaryContainer,
          child: Icon(
            completed
                ? Icons.check
                : inProgress
                ? Icons.play_arrow
                : Icons.checklist_outlined,
            color: completed
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          session.topicName ?? session.subjectName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatStart(session.start)} · ${session.durationMin} min',
              style: theme.textTheme.bodySmall,
            ),
            if (studied > 0 && !completed) ...[
              const SizedBox(height: 4),
              LinearProgressIndicator(value: progress, minHeight: 4),
              const SizedBox(height: 2),
              Text(
                'Estudiado: ${_formatTime(studied)} · '
                'restante: ${_formatTime((total - studied).clamp(0, total).toInt())}',
                style: theme.textTheme.labelSmall,
              ),
            ],
            const SizedBox(height: 2),
            Text(
              completed
                  ? 'Completada'
                  : inProgress
                  ? 'En curso'
                  : session.state == 'replanificada'
                  ? 'Replanificada'
                  : 'Pendiente',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: completed
                    ? theme.colorScheme.primary
                    : inProgress
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: completed
            ? null
            : Icon(
                selected ? Icons.expand_less : Icons.play_circle_outline,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
        onTap: onTap,
      ),
    );
  }
}

class _TaskTimerCard extends StatelessWidget {
  const _TaskTimerCard({
    required this.session,
    required this.elapsedSeconds,
    required this.isRunning,
    required this.formatTime,
    required this.onStart,
    required this.onPause,
    required this.onComplete,
    required this.onFinishEarly,
  });

  final SessionDto session;
  final int elapsedSeconds;
  final bool isRunning;
  final String Function(int) formatTime;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onComplete;
  final VoidCallback onFinishEarly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = session.durationMin * 60;
    final remaining = (total - elapsedSeconds).clamp(0, total).toInt();
    final progress = total == 0
        ? 0.0
        : (elapsedSeconds / total).clamp(0.0, 1.0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.topicName ?? session.subjectName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  isRunning ? 'En curso' : 'En pausa',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isRunning
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    formatTime(remaining),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'restantes de ${session.durationMin} min',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isRunning ? onPause : onStart,
                    icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                    label: Text(isRunning ? 'Pausar' : 'Iniciar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isRunning ? null : onFinishEarly,
                    icon: const Icon(Icons.timer_off_outlined),
                    label: const Text('Terminar antes'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isRunning ? null : onComplete,
                icon: const Icon(Icons.check),
                label: const Text('Dar por completada'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRunning
                  ? 'El tiempo se está guardando. Puedes pausar cuando quieras.'
                  : 'Tiempo acumulado: ${formatTime(elapsedSeconds)}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatTime(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

String _isoDate(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-'
      '${two(value.month)}-${two(value.day)}T00:00:00';
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
