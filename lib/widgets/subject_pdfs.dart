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

  @override
  Widget build(BuildContext context) {
    final documentsAsync = ref.watch(documentsProvider(widget.subjectId));
    final chunksAsync = _selectedDocumentId == null
        ? const AsyncValue<List<String>>.data([])
        : ref.watch(documentChunksProvider(_selectedDocumentId!));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('PDFs', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Documentos PDF agregados a la asignatura',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        documentsAsync.when(
          data: (documents) {
            final pdfs = documents
                .where((document) => document.kind == 'pdf')
                .toList();
            if (pdfs.isEmpty) {
              return const EmptyState(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Sin PDFs',
                message: 'Importa un PDF desde Archivos para leerlo aquí.',
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Documentos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...pdfs.map(
                  (document) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.picture_as_pdf_outlined),
                      ),
                      title: Text(document.name),
                      subtitle: Text(
                        '${document.kind.toUpperCase()} · v${document.version} · ${_status(document)}',
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
                if (_selectedDocumentId != null) ...[
                  const Divider(),
                  ListTile(
                    title: Text('Contenido de «$_selectedDocumentName»'),
                    style: ListTileStyle.drawer,
                  ),
                  ...chunksAsync.when(
                    data: (chunks) => chunks.isEmpty
                        ? [const ListTile(title: Text('Sin texto extraído'))]
                        : chunks.map(
                            (chunk) => ListTile(
                              title: Text(
                                chunk,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                    loading: () => [const ListTile(title: Text('Cargando…'))],
                    error: (error, _) => [
                      ListTile(title: Text('No se pudo abrir: $error')),
                    ],
                  ),
                ],
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
