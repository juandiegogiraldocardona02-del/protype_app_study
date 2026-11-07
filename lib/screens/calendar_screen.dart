import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart';
import '../widgets/empty_state.dart';

enum _CalendarView { month, week, day }

const List<String> _monthNames = <String>[
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const List<String> _weekdayNames = <String>[
  'lun',
  'mar',
  'mié',
  'jue',
  'vie',
  'sáb',
  'dom',
];

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _CalendarView _view = _CalendarView.month;
  late DateTime _anchor = _dateOnly(DateTime.now());
  int? _subjectId;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return const EmptyState(
        icon: Icons.calendar_month_outlined,
        title: 'Calendario',
        message: 'Crea un perfil para ver tu calendario de estudio.',
      );
    }

    final subjects =
        ref.watch(subjectsProvider(profile.id)).asData?.value ??
        const <SubjectDto>[];
    if (_subjectId != null &&
        !subjects.any((subject) => subject.id == _subjectId)) {
      _subjectId = null;
    }

    final (start, end) = _range();
    final query = SessionQuery(
      profileId: profile.id,
      subjectId: _subjectId,
      start: _iso(start),
      end: _iso(end),
    );
    final sessions = ref.watch(sessionsProvider(query));

    return Column(
      children: [
        _buildToolbar(context, subjects),
        Expanded(
          child: sessions.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              icon: Icons.error_outline,
              title: 'No se pudo cargar el calendario',
              message: '$error',
            ),
            data: (items) => switch (_view) {
              _CalendarView.month => _buildMonth(items),
              _CalendarView.week => _buildWeek(items),
              _CalendarView.day => _buildDay(items),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context, List<SubjectDto> subjects) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<_CalendarView>(
            segments: const [
              ButtonSegment(value: _CalendarView.month, label: Text('Mes')),
              ButtonSegment(value: _CalendarView.week, label: Text('Semana')),
              ButtonSegment(value: _CalendarView.day, label: Text('Día')),
            ],
            selected: {_view},
            onSelectionChanged: (selection) =>
                setState(() => _view = selection.first),
          ),
          IconButton(
            tooltip: 'Anterior',
            onPressed: () => _shift(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(_title(), style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            tooltip: 'Siguiente',
            onPressed: () => _shift(1),
            icon: const Icon(Icons.chevron_right),
          ),
          TextButton(
            onPressed: () =>
                setState(() => _anchor = _dateOnly(DateTime.now())),
            child: const Text('Hoy'),
          ),
          DropdownButton<int?>(
            value: _subjectId,
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Todas las asignaturas'),
              ),
              for (final subject in subjects)
                DropdownMenuItem<int?>(
                  value: subject.id,
                  child: Text(subject.name),
                ),
            ],
            onChanged: (value) => setState(() => _subjectId = value),
          ),
          const _Legend(),
        ],
      ),
    );
  }

  Widget _buildMonth(List<SessionDto> sessions) {
    final first = DateTime(_anchor.year, _anchor.month, 1);
    final daysInMonth = DateTime(_anchor.year, _anchor.month + 1, 0).day;
    final leading = first.weekday - 1;
    final byDay = _groupByDay(sessions);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.25,
      ),
      itemCount: leading + daysInMonth,
      itemBuilder: (context, index) {
        if (index < leading) {
          return const SizedBox.shrink();
        }
        final dayNumber = index - leading + 1;
        final date = DateTime(_anchor.year, _anchor.month, dayNumber);
        final daySessions = byDay[_dateKey(date)] ?? const <SessionDto>[];
        final isToday = _sameDay(date, DateTime.now());
        return InkWell(
          onTap: () => setState(() {
            _anchor = date;
            _view = _CalendarView.day;
          }),
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isToday
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: isToday ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$dayNumber'),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 3,
                  runSpacing: 3,
                  children: [
                    for (final session in daySessions.take(4))
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _stateColor(context, session.state),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (daySessions.length > 4)
                      Text(
                        '+${daySessions.length - 4}',
                        style: const TextStyle(fontSize: 9),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeek(List<SessionDto> sessions) {
    final (start, _) = _range();
    final byDay = _groupByDay(sessions);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = DateTime(start.year, start.month, start.day + index);
        final daySessions = byDay[_dateKey(day)] ?? const <SessionDto>[];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_weekdayNames[day.weekday - 1]} ${_shortDate(day)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                if (daySessions.isEmpty)
                  Text(
                    'Sin sesiones',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  for (final session in daySessions)
                    _sessionTile(context, session, dense: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDay(List<SessionDto> sessions) {
    final day = _dateOnly(_anchor);
    final daySessions = sessions
        .where((session) => _sameDay(_startOf(session), day))
        .toList();
    if (daySessions.isEmpty) {
      return EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Sin sesiones el ${_shortDate(day)}',
        message:
            'Genera un plan desde la agenda de una asignatura o cambia de día.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${_weekdayNames[day.weekday - 1]} ${_shortDate(day)} · '
          '${daySessions.length} sesiones',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final session in daySessions) _sessionTile(context, session),
      ],
    );
  }

  Widget _sessionTile(
    BuildContext context,
    SessionDto session, {
    bool dense = false,
  }) {
    final completed = session.state == 'completada';
    return ListTile(
      dense: dense,
      leading: Icon(
        completed ? Icons.check_circle : Icons.radio_button_unchecked,
        color: _stateColor(context, session.state),
      ),
      title: Text(session.topicName ?? 'Sesión de estudio'),
      subtitle: Text(
        '${_timeOf(session.start)} · ${session.durationMin} min · '
        '${session.subjectName}'
        '${session.state == 'replanificada' ? ' · replanificada' : ''}',
      ),
      trailing: IconButton(
        tooltip: completed ? 'Marcar pendiente' : 'Marcar completada',
        icon: Icon(completed ? Icons.undo : Icons.done),
        onPressed: () => _toggle(context, session, completed),
      ),
      onTap: () => _toggle(context, session, completed),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    SessionDto session,
    bool completed,
  ) async {
    try {
      await ref
          .read(planActionsProvider)
          .setSessionState(session.id, completed ? 'pendiente' : 'completada');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar: $error')),
        );
      }
    }
  }

  (DateTime, DateTime) _range() {
    switch (_view) {
      case _CalendarView.month:
        final start = DateTime(_anchor.year, _anchor.month, 1);
        return (start, DateTime(_anchor.year, _anchor.month + 1, 1));
      case _CalendarView.week:
        final start = DateTime(
          _anchor.year,
          _anchor.month,
          _anchor.day - (_anchor.weekday - 1),
        );
        return (start, DateTime(start.year, start.month, start.day + 7));
      case _CalendarView.day:
        final start = _dateOnly(_anchor);
        return (start, DateTime(start.year, start.month, start.day + 1));
    }
  }

  void _shift(int direction) {
    setState(() {
      switch (_view) {
        case _CalendarView.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
          break;
        case _CalendarView.week:
          _anchor = DateTime(
            _anchor.year,
            _anchor.month,
            _anchor.day + 7 * direction,
          );
          break;
        case _CalendarView.day:
          _anchor = DateTime(
            _anchor.year,
            _anchor.month,
            _anchor.day + direction,
          );
          break;
      }
    });
  }

  String _title() {
    switch (_view) {
      case _CalendarView.month:
        return '${_monthNames[_anchor.month - 1]} ${_anchor.year}';
      case _CalendarView.week:
        final (start, end) = _range();
        return '${_shortDate(start)} – '
            '${_shortDate(DateTime(end.year, end.month, end.day - 1))}';
      case _CalendarView.day:
        return _shortDate(_anchor);
    }
  }

  Map<String, List<SessionDto>> _groupByDay(List<SessionDto> sessions) {
    final result = <String, List<SessionDto>>{};
    for (final session in sessions) {
      final key = session.start.length >= 10
          ? session.start.substring(0, 10)
          : session.start;
      result.putIfAbsent(key, () => <SessionDto>[]).add(session);
    }
    return result;
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      children: [
        _LegendDot(
          label: 'Pendiente',
          color: _stateColor(context, 'pendiente'),
        ),
        _LegendDot(label: 'Hecha', color: _stateColor(context, 'completada')),
        _LegendDot(
          label: 'Replanificada',
          color: _stateColor(context, 'replanificada'),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

Color _stateColor(BuildContext context, String state) {
  switch (state) {
    case 'completada':
      return Colors.green.shade600;
    case 'replanificada':
      return Colors.orange.shade700;
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _startOf(SessionDto session) {
  return DateTime.tryParse(session.start) ?? DateTime(1970);
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _iso(DateTime value) => '${_dateKey(value)}T00:00:00';

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/'
    '${value.year}';

String _timeOf(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return iso;
  }
  return '${parsed.hour.toString().padLeft(2, '0')}:'
      '${parsed.minute.toString().padLeft(2, '0')}';
}
