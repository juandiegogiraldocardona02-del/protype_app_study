import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/bridge.dart';
import '../state/providers.dart';
import 'dialogs.dart';

class BackupPanel extends ConsumerStatefulWidget {
  const BackupPanel({super.key});

  @override
  ConsumerState<BackupPanel> createState() => _BackupPanelState();
}

class _BackupPanelState extends ConsumerState<BackupPanel> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        _message('No se pudo completar la operación: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _exportBackup() async {
    final directory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Elegir carpeta para la copia global',
    );
    if (directory == null || !mounted) {
      return;
    }
    await _run(() async {
      final result = await ref
          .read(backupActionsProvider)
          .exportBackup(directory);
      if (!mounted) {
        return;
      }
      _message('${result.message} Archivo: ${result.path}');
    });
  }

  Future<void> _restoreBackup() async {
    final path = await _pickFile(
      dialogTitle: 'Seleccionar copia global',
      extensions: const ['studybackup', 'zip'],
    );
    if (path == null || !mounted) {
      return;
    }
    await _run(() async {
      final preview = await ref
          .read(backupActionsProvider)
          .inspectBackup(path);
      if (!mounted) {
        return;
      }
      final confirmed = await showConfirmDialog(
        context,
        title: 'Restaurar copia global',
        message:
            '${preview.message}\n\n${_counts(preview.counts)}\n\n'
            'Perfiles: ${preview.profileNames.join(', ')}',
        confirmLabel: preview.conflict ? 'Reemplazar todo' : 'Restaurar',
      );
      if (!confirmed || !mounted) {
        return;
      }
      final result = await ref
          .read(backupActionsProvider)
          .restoreBackup(path, preview.conflict);
      if (!mounted) {
        return;
      }
      _message(result.message);
    });
  }

  Future<void> _importStudyPlan() async {
    final profile = ref.read(activeProfileProvider);
    if (profile == null) {
      _message('Crea o selecciona un perfil antes de importar.');
      return;
    }
    final path = await _pickFile(
      dialogTitle: 'Seleccionar asignatura .studyplan',
      extensions: const ['studyplan'],
    );
    if (path == null || !mounted) {
      return;
    }
    await _run(() async {
      final preview = await ref
          .read(backupActionsProvider)
          .inspectStudyPlan(path, profile.id);
      if (!mounted) {
        return;
      }
      final confirmed = await showConfirmDialog(
        context,
        title: 'Importar asignatura',
        message:
            '${preview.message}\n\n${_counts(preview.counts)}\n\n'
            'Perfil de destino: ${profile.name}',
        confirmLabel: preview.conflict ? 'Reemplazar' : 'Importar',
      );
      if (!confirmed || !mounted) {
        return;
      }
      var result = await ref
          .read(backupActionsProvider)
          .importStudyPlan(path, profile.id, preview.conflict);
      if (result.requiresConfirmation && mounted) {
        final again = await showConfirmDialog(
          context,
          title: 'Confirmar reemplazo',
          message: result.message,
          confirmLabel: 'Reemplazar',
        );
        if (!again || !mounted) {
          return;
        }
        result = await ref
            .read(backupActionsProvider)
            .importStudyPlan(path, profile.id, true);
      }
      if (!mounted) {
        return;
      }
      _message(result.message);
    });
  }

  Future<String?> _pickFile({
    required String dialogTitle,
    required List<String> extensions,
  }) async {
    final files = await FilePicker.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (files.isEmpty) {
      return null;
    }
    return files.first.path;
  }

  String _counts(BackupCountsDto counts) {
    return '${counts.profiles} perfiles · ${counts.subjects} asignaturas · '
        '${counts.documents} documentos · ${counts.sessions} sesiones · '
        '${counts.flashcards} tarjetas · ${counts.reviews} repasos';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.inventory_2_outlined),
            title: Text('Copias de seguridad'),
            subtitle: Text(
              'Exporta una asignatura o todo el dispositivo. Los archivos se '
              'guardan localmente y verifican su integridad al restaurar.',
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _exportBackup,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Exportar copia global'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _restoreBackup,
                  icon: const Icon(Icons.restore_outlined),
                  label: const Text('Restaurar copia global'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _importStudyPlan,
                  icon: const Icon(Icons.file_open_outlined),
                  label: const Text('Importar asignatura'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
