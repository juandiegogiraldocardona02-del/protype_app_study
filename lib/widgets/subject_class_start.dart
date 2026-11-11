import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart' show SessionDto;
import 'empty_state.dart';

class SubjectClassStartPanel extends ConsumerStatefulWidget {
  const SubjectClassStartPanel({super.key, required this.subjectId});

  final int subjectId;

  @override
  ConsumerState<SubjectClassStartPanel> createState() =>
      _SubjectClassStartPanelState();
}

class _SubjectClassStartPanelState
    extends ConsumerState<SubjectClassStartPanel> {
  int? _selectedSessionId;
  Timer? _timer;
  int _elapsedSeconds = 0;
  int _totalSeconds = 0;
  bool _isRunning = false;
  String? _selectedPath;

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Seleccionar archivo para la clase',
      type: FileType.custom,
      allowedExtensions: const [
        'pdf',
        'txt',
        'mp3',
        'wav',
        'm4a',
        'aac',
        'ogg',
        'flac',
      ],
    );
    if (files.isEmpty) {
      return;
    }
    final path = files.first.path;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la ruta local.')),
        );
      }
      return;
    }
    setState(() => _selectedPath = path);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Archivo listo: $path')));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _selectSession(SessionDto session) {
    _timer?.cancel();
    setState(() {
      _selectedSessionId = session.id;
      _elapsedSeconds = 0;
      _totalSeconds = session.durationMin * 60;
      _isRunning = false;
    });
  }

  void _startTimer(int totalSeconds) {
    if (_isRunning || _selectedSessionId == null) {
      return;
    }
    _timer?.cancel();
    setState(() {
      _isRunning = true;
      _totalSeconds = totalSeconds;
      if (_totalSeconds <= 0) {
        _totalSeconds = 1;
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds++;
        if (_elapsedSeconds >= _totalSeconds) {
          _elapsedSeconds = _totalSeconds;
        }
      });
      if (_elapsedSeconds >= _totalSeconds) {
        _timer?.cancel();
        unawaited(_handleTimeCompleted());
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _elapsedSeconds = 0;
    });
  }

  Future<void> _handleTimeCompleted() async {
    if (!mounted) {
      return;
    }
    setState(() => _isRunning = false);
    unawaited(SystemSound.play(SystemSoundType.alert));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Tiempo de estudio completado!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await _completeSession(
      message: 'Sesión completada al terminar el tiempo. ¡XP otorgado!',
    );
  }

  Future<void> _finishEarly(SessionDto session) async {
    final id = _selectedSessionId;
    if (id == null) {
      return;
    }
    _timer?.cancel();
    setState(() => _isRunning = false);
    if (_elapsedSeconds <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aún no hay tiempo estudiado que descontar.'),
          ),
        );
      }
      return;
    }
    final studiedMinutes = (_elapsedSeconds / 60).ceil();
    final remainingMinutes = session.durationMin - studiedMinutes;
    try {
      if (remainingMinutes <= 0) {
        await ref.read(planActionsProvider).setSessionState(id, 'completada');
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tiempo estudiado descontado. ¡Sesión completada!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {
          _elapsedSeconds = 0;
          _selectedSessionId = null;
        });
      } else {
        await ref
            .read(planActionsProvider)
            .setSessionDuration(id, remainingMinutes);
        if (!mounted) {
          return;
        }
        setState(() => _elapsedSeconds = 0);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tiempo descontado. Quedan $remainingMinutes min en la sesión.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar la sesión: $error')),
      );
    }
  }

  Future<void> _completeSession({String? message}) async {
    final id = _selectedSessionId;
    if (id == null) {
      return;
    }
    _timer?.cancel();
    setState(() => _isRunning = false);
    try {
      await ref.read(planActionsProvider).setSessionState(id, 'completada');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message ?? 'Sesión completada. ¡XP otorgado!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {
        _elapsedSeconds = 0;
        _selectedSessionId = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar la sesión: $error')),
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

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return const EmptyState(
        icon: Icons.school_outlined,
        title: 'Inicio de clase',
        message: 'Crea un perfil para comenzar a registrar tus sesiones.',
      );
    }

    final now = DateTime.now();
    final query = SessionQuery(
      profileId: profile.id,
      subjectId: widget.subjectId,
      start: _isoDate(now.subtract(const Duration(days: 365))),
      end: _isoDate(now.add(const Duration(days: 365))),
    );
    final sessionsAsync = ref.watch(sessionsProvider(query));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Inicio de clase',
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Selecciona una sesión programada para iniciar tu estudio.',
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Abre el archivo para la clase',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecciona el documento o audio que usarás al comenzar.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Abrir archivo'),
                ),
                if (_selectedPath != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _selectedPath!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Sesiones programadas',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        sessionsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'No se pudo cargar el plan de estudio',
            message: error.toString(),
          ),
          data: (sessions) {
            if (sessions.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'Sin sesiones programadas',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea un plan de estudio desde la pestaña Agenda para '
                        'comenzar a estudiar.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final selected = sessions
                .where((session) => session.id == _selectedSessionId)
                .firstOrNull;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final session in sessions)
                  _SessionCard(
                    session: session,
                    selected: session.id == _selectedSessionId,
                    onTap: () => _selectSession(session),
                  ),
                if (selected != null) ...[
                  const SizedBox(height: 8),
                  _TimerCard(
                    session: selected,
                    elapsedSeconds: _elapsedSeconds,
                    totalSeconds: selected.durationMin * 60,
                    isRunning: _isRunning,
                    formatTime: _formatTime,
                    onStart: () => _startTimer(selected.durationMin * 60),
                    onPause: _pauseTimer,
                    onReset: _resetTimer,
                    onFinishEarly: () => _finishEarly(selected),
                    onComplete: () => _completeSession(),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final SessionDto session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completed = session.state == 'completada';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.schedule,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          session.topicName ?? session.subjectName,
          style: theme.textTheme.titleMedium,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatStart(session.start)} · ${session.durationMin} min',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              completed ? 'Completada' : 'Pendiente',
              style: TextStyle(
                fontSize: 11,
                color: completed
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.play_circle,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({
    required this.session,
    required this.elapsedSeconds,
    required this.totalSeconds,
    required this.isRunning,
    required this.formatTime,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onFinishEarly,
    required this.onComplete,
  });

  final SessionDto session;
  final int elapsedSeconds;
  final int totalSeconds;
  final bool isRunning;
  final String Function(int) formatTime;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onFinishEarly;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = (totalSeconds - elapsedSeconds)
        .clamp(0, totalSeconds)
        .toInt();
    return Card(
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text(
                    formatTime(remaining),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'de ${session.durationMin} min de sesión',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: totalSeconds == 0
                  ? 0.0
                  : (elapsedSeconds / totalSeconds).clamp(0.0, 1.0).toDouble(),
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
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reiniciar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isRunning ? null : onFinishEarly,
                    icon: const Icon(Icons.timer_off_outlined),
                    label: const Text('Terminar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isRunning ? null : onComplete,
                    icon: const Icon(Icons.check),
                    label: const Text('Completar sesión'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isRunning
                  ? 'Estudio en progreso...'
                  : elapsedSeconds > 0
                  ? 'Tiempo acumulado: ${formatTime(elapsedSeconds)}'
                  : 'No hay tiempo registrado aún.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} '
      '${two(local.hour)}:${two(local.minute)}';
}
