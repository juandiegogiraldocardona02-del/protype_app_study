import 'package:flutter/material.dart';

import '../widgets/empty_state.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.folder_open_outlined,
      title: 'Biblioteca',
      message:
          'Importación de PDF, DOCX, PPTX, XLSX, TXT, imágenes y audio, con OCR '
          'local y búsqueda por asignatura. Llega en la etapa E2.',
    );
  }
}
