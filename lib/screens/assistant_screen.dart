import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.smart_toy_outlined,
      title: 'Asistente IA local',
      message:
          'El asistente responderá solo con los documentos de la asignatura '
          'activa y citará la fuente. Requiere instalar un modelo GGUF Q4_K_M '
          'de forma opcional (etapa E6) y funciona 100 % sin conexión.',
    );
  }
}
