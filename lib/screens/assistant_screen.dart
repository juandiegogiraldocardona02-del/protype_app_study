import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart';
import '../widgets/empty_state.dart';

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final TextEditingController _question = TextEditingController();
  int? _selectedSubjectId;
  bool _documentsOnly = true;
  bool _loading = false;
  AssistantAnswerDto? _answer;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _ask(int subjectId) async {
    final text = _question.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _answer = null;
    });
    try {
      final answer = await ref
          .read(assistantActionsProvider)
          .ask(subjectId, text, _documentsOnly);
      if (!mounted) {
        return;
      }
      setState(() => _answer = answer);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final subjects = ref.watch(subjectsProvider(profile.id));

    return subjects.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'No se pudieron cargar las asignaturas',
        message: error.toString(),
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.smart_toy_outlined,
            title: 'Asistente IA local',
            message:
                'El asistente responde usando los documentos de una '
                'asignatura. Crea una asignatura e importa material para '
                'empezar.',
            action: FilledButton.icon(
              onPressed: () =>
                  ref.read(navigationIndexProvider.notifier).select(1),
              icon: const Icon(Icons.add),
              label: const Text('Ir a Mis materias'),
            ),
          );
        }
        final selected = items.any((item) => item.id == _selectedSubjectId)
            ? _selectedSubjectId!
            : items.first.id;
        final canAsk = !_loading && _question.text.trim().isNotEmpty;
        final status = ref.watch(aiStatusProvider);

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Asistente IA local',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Responde sin conexión y distingue entre documentos de la '
              'asignatura y conocimiento general del modelo.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            status.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _StatusCard(
                available: false,
                title: 'No se pudo comprobar el modelo',
                message: error.toString(),
              ),
              data: (value) => _StatusCard(
                available: value.available,
                title: value.available
                    ? 'Modelo local listo'
                    : 'Modelo local no instalado',
                message: value.message,
                details: value.available
                    ? value.modelPath
                    : 'Carpeta de modelos: ${value.modelsDir}',
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey<int>(selected),
                            initialValue: selected,
                            decoration: const InputDecoration(
                              labelText: 'Asignatura',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final subject in items)
                                DropdownMenuItem<int>(
                                  value: subject.id,
                                  child: Text(subject.name),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedSubjectId = value;
                                _answer = null;
                                _error = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Tooltip(
                          message:
                              'Si está activo, el asistente solo responde con '
                              'los documentos de la asignatura.',
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: _documentsOnly,
                                onChanged: (value) =>
                                    setState(() => _documentsOnly = value),
                              ),
                              const SizedBox(width: 8),
                              const Text('Solo documentos'),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _question,
                      minLines: 2,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Pregunta',
                        hintText: '¿Qué función tiene la mitocondria?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: canAsk ? () => _ask(selected) : null,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(_loading ? 'Generando…' : 'Preguntar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: ListTile(
                  leading: Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  title: Text(
                    'No se pudo obtener la respuesta',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  subtitle: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ],
            if (_answer != null) ...[
              const SizedBox(height: 16),
              _AnswerCard(answer: _answer!),
            ],
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.available,
    required this.title,
    required this.message,
    this.details,
  });

  final bool available;
  final String title;
  final String message;
  final String? details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Icon(
          available ? Icons.check_circle_outline : Icons.info_outline,
          color: available
              ? theme.colorScheme.primary
              : theme.colorScheme.tertiary,
        ),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (details != null) ...[
              const SizedBox(height: 4),
              SelectableText(details!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer});

  final AssistantAnswerDto answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fromDocuments = answer.origin == 'documentos';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  fromDocuments
                      ? Icons.menu_book_outlined
                      : Icons.psychology_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fromDocuments
                        ? 'Fuente: documentos de la asignatura'
                        : 'Conocimiento general del modelo',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(answer.answer, style: theme.textTheme.bodyLarge),
            if (answer.sources.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Fuentes citadas', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final source in answer.sources)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(source.label),
                      subtitle: Text(source.excerpt),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
