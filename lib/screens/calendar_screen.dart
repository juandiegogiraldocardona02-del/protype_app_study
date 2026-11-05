import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.calendar_month_outlined,
      title: 'Calendario de estudio',
      message:
          'Vistas mensual, semanal y diaria con filtro por asignatura e '
          'indicadores de estado. Llega en la etapa E3 junto con la '
          'replanificación automática.',
    );
  }
}
