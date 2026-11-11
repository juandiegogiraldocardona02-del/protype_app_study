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
  final Set<int> _selectedChunkIndexes = {};
  String? _dateError;
  DateTime? _selectedDate;
  int _durationMinutes = 60;
  bool _importing = false;

  Future<void> _pickAndImport() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Seleccionar PDF para abrir',
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (result.isEmpty || !mounted) return;
    final path = result.first.path;
    if (path == null) return;
    setState(() => _importing = true);
    try {
      await ref.read(documentActionsProvider).import(widget.subjectId, path);
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

  Future<void> _addSelectedToPlan() async {
    if (_selectedChunkIndexes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona al menos un punto')),
      );
      return;
    }
    if (_selectedDate == null) {
      setState(() => _dateError = 'Selecciona una fecha');
      return;
    }

    final settings = await ref.read(
      planSettingsProvider(widget.subjectId).future,
    );
    final allChunks = await ref.read(
      documentChunksProvider(_selectedDocumentId!).future,
    );
    final selectedChunks = allChunks
        .asMap()
        .entries
        .where((e) => _selectedChunkIndexes.contains(e.key))
        .map((e) => e.value)
        .toList();

    final sessionsToSave = <PlannedSessionDto>[];
    for (var i = 0; i < selectedChunks.length; i++) {
      final start = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        settings.startHour,
        i * settings.sessionMinutes ~/ 60,
        (i * settings.sessionMinutes) % 60,
      );
      sessionsToSave.add(
        PlannedSessionDto(
          topicId: null,
          topicName: 'PDF: $_selectedDocumentName - Punto ${i + 1}',
          start: start.toUtc().toIso8601String(),
          durationMin: settings.sessionMinutes,
          state: 'pendiente',
        ),
      );
    }

    await ref.read(planActionsProvider).save(widget.subjectId, sessionsToSave);
    if (!mounted) return;
    setState(() {
      _selectedChunkIndexes.clear();
      _selectedDocumentId = null;
      _selectedDocumentName = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Se agregaron ${sessionsToSave.length} sesiones al plan de estudio',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _status(DocumentDto document) {
    if (document.extractionStatus == 'ok') {
      return '${document.textChars} caracteres';
    }
    return document.extractionStatus;
  }

  @override
  Widget build(BuildContext context) {
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
        ref
            .watch(documentsProvider(widget.subjectId))
            .when(
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
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
                              onTap: () {
                                setState(() {
                                  _selectedDocumentId = document.id;
                                  _selectedDocumentName = document.name;
                                });
                              },
                            ),
                            if (_selectedDocumentId == document.id) ...[
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Contenido de «${document.name}»',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text(
                                          'Puntos del documento',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _selectedChunkIndexes.clear();
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.clear_all,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Deseleccionar todo',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _chunksList(document.id),
                                    const SizedBox(height: 16),
                                    _planSection(context),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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

  Widget _chunksList(int documentId) {
    return FutureBuilder<List<String>>(
      future: ref.read(documentChunksProvider(documentId).future),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const ListTile(
            title: Text('No se pudieron cargar los puntos del PDF'),
          );
        }
        final chunks = snapshot.data!;
        if (chunks.isEmpty) {
          return const ListTile(title: Text('Sin texto extraído'));
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < chunks.length; i++)
              CheckboxListTile(
                title: Text('Punto ${i + 1}'),
                subtitle: Text(
                  chunks[i],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: _selectedChunkIndexes.contains(i),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedChunkIndexes.add(i);
                    } else {
                      _selectedChunkIndexes.remove(i);
                    }
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
              ),
          ],
        );
      },
    );
  }

  Widget _planSection(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Programar en el plan de estudio',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Fecha: '),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        _selectedDate = picked;
                        _dateError = null;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _selectedDate != null
                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                        : 'Elegir fecha',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Duración (min): '),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                      text: _durationMinutes.toString(),
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        setState(() => _durationMinutes = parsed);
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_dateError != null) ...[
              const SizedBox(height: 8),
              Text(
                _dateError!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed:
                  _selectedDocumentId == null ||
                      _selectedChunkIndexes.isEmpty ||
                      _selectedDate == null
                  ? null
                  : _addSelectedToPlan,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Agregar al plan de estudio'),
            ),
          ],
        ),
      ),
    );
  }
}
