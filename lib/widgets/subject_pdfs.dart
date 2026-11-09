import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart';
import '../widgets/empty_state.dart';

class SubjectPdfsPanel extends ConsumerStatefulWidget {
  const SubjectPdfsPanel({super.key, required this.subjectId});

  final int subjectId;

  @override
  ConsumerState<SubjectPdfsPanel> createState() => _SubjectPdfsPanelState();
}

class _SubjectPdfsPanelState extends ConsumerState<SubjectPdfsPanel> {
  int? _selectedDocumentId;
  String? _selectedDocumentName;
  bool _importing = false;

  Future<void> _pickAndImport() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Seleccionar PDF para abrir',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (files.isEmpty) {
      return;
    }
    setState(() => _importing = true);
    try {
      for (final file in files) {
        final path = file.path;
        if (path == null) continue;
        await ref.read(documentActionsProvider).import(widget.subjectId, path);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF importado correctamente')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo importar: $error')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsProvider(widget.subjectId));
    final chunksAsync = _selectedDocumentId == null
        ? const AsyncValue<List<String>>.data([])
        : ref.watch(documentChunksProvider(_selectedDocumentId!));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'PDFs',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
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
              label: Text(_importing ? 'Importando' : 'Importar PDF'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        documentsAsync.when(
          data: (documents) {
            final pdfs = documents
                .where((document) => document.kind == 'pdf')
                .toList();
            if (pdfs.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sin PDFs',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Importa un PDF desde aquí para leer su contenido.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _pickAndImport,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Importar PDF'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Documentos PDF',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...pdfs.map(
                  (document) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primaryContainer,
                        child: const Icon(
                          Icons.picture_as_pdf_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        document.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${document.kind.toUpperCase()} · v${document.version} · ${_status(document)}',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_new),
                        tooltip: 'Abrir PDF',
                        onPressed: () {
                          setState(() {
                            _selectedDocumentId = document.id;
                            _selectedDocumentName = document.name;
                          });
                        },
                      ),
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  title: Text(
                    'Contenido de «$_selectedDocumentName»',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  style: ListTileStyle.drawer,
                ),
                ...chunksAsync.when(
                  data: (chunks) => chunks.isEmpty
                      ? [const ListTile(title: Text('Sin texto extraído'))]
                      : chunks.map(
                          (chunk) => ListTile(
                            title: Text(
                              chunk,
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                  loading: () => const [ListTile(title: Text('Cargando…'))],
                  error: (error, _) => [
                    ListTile(title: Text('No se pudo abrir: $error')),
                  ],
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            icon: Icons.error_outline,
            title: 'No se pudo cargar la biblioteca',
            message: error.toString(),
          ),
        ),
      ],
    );
  }

  String _status(DocumentDto document) {
    if (document.extractionStatus == 'ok') {
      return '${document.textChars} caracteres';
    }
    return document.extractionStatus;
  }
}
