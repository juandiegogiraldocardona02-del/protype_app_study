import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/repository.dart';

class SubjectClassStartPanel extends ConsumerStatefulWidget {
  const SubjectClassStartPanel({super.key, required this.subject});

  final SubjectDto subject;

  @override
  ConsumerState<SubjectClassStartPanel> createState() =>
      _SubjectClassStartPanelState();
}

class _SubjectClassStartPanelState
    extends ConsumerState<SubjectClassStartPanel> {
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
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Inicio de clase', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
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
      ],
    );
  }
}
