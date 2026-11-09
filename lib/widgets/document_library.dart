import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart';
import 'dialogs.dart';
import 'empty_state.dart';

const List<String> _allowedExtensions = <String>[
  'pdf',
  'txt',
  'png',
  'jpg',
  'jpeg',
  'bmp',
  'tif',
  'tiff',
  'webp',
  'mp3',
  'wav',
  'm4a',
  'aac',
  'ogg',
  'flac',
];

class DocumentLibrary extends ConsumerStatefulWidget {
  const DocumentLibrary({super.key, required this.subjectId});

  final int subjectId;

  @override
  ConsumerState<DocumentLibrary> createState() => _DocumentLibraryState();
}

class _DocumentLibraryState extends ConsumerState<DocumentLibrary> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String _filter = 'todos';
  bool _importing = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickAndImport() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Importar documentos de la asignatura',
      type: FileType.custom,
      allowedExtensions: _allowedExtensions,
    );
    if (files.isEmpty) {
      return;
    }

    setState(() => _importing = true);
    var imported = 0;
    final notices = <String>[];
    for (final file in files) {
      final path = file.path;
      if (path == null) {
        notices.add('${file.name}: no se pudo obtener la ruta local.');
        continue;
      }
      try {
        final outcome = await ref
            .read(documentActionsProvider)
            .import(widget.subjectId, path);
        if (outcome.duplicate) {
          notices.add(outcome.message);
        } else {
          imported += 1;
          if (outcome.document.extractionStatus != 'ok') {
            notices.add('${outcome.document.name}: ${outcome.message}');
          }
        }
      } catch (error) {
        notices.add('${file.name}: ${_describe(error)}');
      }
    }
    if (!mounted) {
      return;
    }
    setState(() => _importing = false);

    final summary = imported > 0
        ? 'Documentos importados: $imported.'
        : 'No se importó ningún documento nuevo.';
    final message = notices.isEmpty ? summary : '$summary ${notices.join(' ')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
    );
  }

  Future<void> _delete(int id, String name) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar documento',
      message:
          '¿Eliminar «$name» de la biblioteca? Las flashcards y sesiones '
          'derivadas se conservarán marcadas como huérfanas.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref.read(documentActionsProvider).delete(widget.subjectId, id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: ${_describe(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(documentsProvider(widget.subjectId));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar por nombre',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _importing ? null : _pickAndImport,
                icon: _importing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_outlined),
                label: Text(_importing ? 'Importando' : 'Importar'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              children: [
                for (final option in const <({String key, String label})>[
                  (key: 'todos', label: 'Todos'),
                  (key: 'pdf', label: 'PDF'),
                  (key: 'txt', label: 'TXT'),
                  (key: 'imagen', label: 'Imágenes'),
                  (key: 'audio', label: 'Audio'),
                ])
                  ChoiceChip(
                    label: Text(option.label),
                    selected: _filter == option.key,
                    onSelected: (_) => setState(() => _filter = option.key),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: documents.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              icon: Icons.error_outline,
              title: 'No se pudo cargar la biblioteca',
              message: _describe(error),
            ),
            data: (items) {
              final filtered = items.where((document) {
                final matchesFilter =
                    _filter == 'todos' || document.kind == _filter;
                final matchesQuery =
                    _query.isEmpty ||
                    document.name.toLowerCase().contains(_query.toLowerCase());
                return matchesFilter && matchesQuery;
              }).toList();

              if (items.isEmpty) {
                return EmptyState(
                  icon: Icons.folder_open_outlined,
                  title: 'Biblioteca vacía',
                  message:
                      'Importa PDF, TXT, imágenes escaneadas o audio. La '
                      'extracción de texto, el OCR y la transcripción opcionales '
                      'funcionan sin conexión.',
                  action: FilledButton.icon(
                    onPressed: _importing ? null : _pickAndImport,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Importar documento'),
                  ),
                );
              }
              if (filtered.isEmpty) {
                return const EmptyState(
                  icon: Icons.search_off,
                  title: 'Sin resultados',
                  message: 'Prueba con otro nombre o cambia el filtro de tipo.',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final document = filtered[index];
                  final ok = document.extractionStatus == 'ok';
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(_iconFor(document.kind)),
                      ),
                      title: Text(
                        document.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${document.kind.toUpperCase()} · v${document.version} · '
                        '${_describeStatus(document)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ok
                            ? null
                            : TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Eliminar documento',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(document.id, document.name),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'txt':
        return Icons.description_outlined;
      case 'imagen':
        return Icons.image_outlined;
      case 'audio':
        return Icons.audiotrack_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _describeStatus(DocumentDto document) {
    switch (document.extractionStatus) {
      case 'ok':
        return '${document.textChars} caracteres';
      case 'ocr_no_disponible':
        return 'sin OCR';
      case 'whisper_no_disponible':
        return 'sin transcripción';
      case 'whisper_sin_modelo':
        return 'sin modelo de voz';
      case 'audio_sin_ffmpeg':
        return 'sin ffmpeg';
      case 'vacio':
        return 'sin texto';
      case 'error':
        return 'error de extracción';
      default:
        return document.extractionStatus;
    }
  }
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
