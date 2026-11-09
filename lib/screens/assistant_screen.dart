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
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asistente IA local',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Responde sin conexión y distingue entre documentos '
                        'de la asignatura y conocimiento general.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _ModelStatusCard(status: status),
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

class _ModelStatusCard extends StatelessWidget {
  const _ModelStatusCard({required this.status});

  final AsyncValue<AiStatusDto> status;

  @override
  Widget build(BuildContext context) {
    return status.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _StatusCard(
        available: false,
        title: 'No se pudo comprobar el modelo',
        message: error.toString(),
        icon: Icons.error_outline,
        color: Theme.of(context).colorScheme.errorContainer,
        textColor: Theme.of(context).colorScheme.onErrorContainer,
      ),
      data: (value) {
        if (value.available) {
          return _StatusCard(
            available: true,
            title: 'Modelo local listo',
            message: value.message,
            details: 'Modelo: ${value.modelPath ?? 'sin ruta'}',
            icon: Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primaryContainer,
            textColor: Theme.of(context).colorScheme.primary,
          );
        }
        return _StatusCard(
          available: false,
          title: 'Modelo local no instalado',
          message:
              'Descarga un modelo GGUF (Qwen2.5-1.5B-Instruct Q4_K_M o '
              'similar) y colócalo en la carpeta de modelos.',
          details: 'Carpeta: ${value.modelsDir}',
          icon: Icons.cloud_off_outlined,
          color: Theme.of(context).colorScheme.tertiaryContainer,
          textColor: Theme.of(context).colorScheme.tertiary,
          hint: 'Sin el modelo, el asistente no genera respuestas.',
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
    this.hint,
    required this.icon,
    required this.color,
    required this.textColor,
  });

  final bool available;
  final String title;
  final String message;
  final String? details;
  final String? hint;
  final IconData icon;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: textColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (details != null) ...[
              const SizedBox(height: 8),
              SelectableText(
                details!,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.75),
                ),
              ),
            ],
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(answer.answer, style: theme.textTheme.bodyLarge),
            if (answer.sources.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Fuentes citadas',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
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
