import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.bar_chart_outlined,
      title: 'Estadísticas',
      message:
          'XP, niveles, rachas, insignias y dominio por tema aparecerán aquí a '
          'medida que avancen las etapas E4 y E5.',
    );
  }
}
