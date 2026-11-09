import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart';

class SubjectAssessmentsPanel extends ConsumerWidget {
  const SubjectAssessmentsPanel({super.key, required this.subject});

  final SubjectDto subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessments = ref.watch(assessmentsProvider(subject.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Evaluaciones',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuestionarios generados desde tus documentos',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Las preguntas se construyen solo con el contenido de la '
                  'biblioteca de esta asignatura y se corrigen en el '
                  'dispositivo, sin conexión.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _generate(context, ref),
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: const Text('Generar cuestionario'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Historial', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        assessments.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) =>
              Text('No se pudo cargar el historial: ${_describe(error)}'),
          data: (items) {
            if (items.isEmpty) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.quiz_outlined),
                  title: Text('Aún no hay evaluaciones'),
                  subtitle: Text(
                    'Genera un cuestionario cuando tengas documentos con texto.',
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final assessment in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: assessment.score >= assessment.threshold
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.errorContainer,
                        child: Icon(
                          assessment.score >= assessment.threshold
                              ? Icons.check_outlined
                              : Icons.close_outlined,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        '${assessment.kind} · '
                        '${(assessment.score * 100).round()}%',
                      ),
                      subtitle: Text(
                        '${assessment.correct}/${assessment.total} aciertos · '
                        'umbral ${(assessment.threshold * 100).round()}% · '
                        '${_formatDate(assessment.date)}',
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    try {
      final proposal = await ref
          .read(assessmentActionsProvider)
          .generate(subject.id, 10);
      if (!context.mounted) {
        return;
      }
      if (proposal.questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se generaron preguntas.')),
        );
        return;
      }
      final result = await showDialog<AssessmentResultDto>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _QuizDialog(
          subjectId: subject.id,
          proposal: proposal,
        ),
      );
      if (result != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_describe(error))));
      }
    }
  }
}

class _QuizDialog extends ConsumerStatefulWidget {
  const _QuizDialog({required this.subjectId, required this.proposal});

  final int subjectId;
  final AssessmentProposalDto proposal;

  @override
  ConsumerState<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends ConsumerState<_QuizDialog> {
  final Map<int, String> _answers = {};
  final Map<int, TextEditingController> _controllers = {};
  double _threshold = 0.6;
  bool _busy = false;
  AssessmentResultDto? _result;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(int id) {
    return _controllers.putIfAbsent(id, TextEditingController.new);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return AlertDialog(
      title: Text(
        result == null
            ? 'Cuestionario (${widget.proposal.questions.length} preguntas)'
            : 'Resultado',
      ),
      content: SizedBox(
        width: 620,
        height: 520,
        child: result == null ? _buildQuestions(context) : _buildResult(result),
      ),
      actions: result == null
          ? [
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _busy ? null : _grade,
                child: Text(_busy ? 'Corrigiendo…' : 'Corregir'),
              ),
            ]
          : [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(result),
                child: const Text('Cerrar'),
              ),
            ],
    );
  }

  Widget _buildQuestions(BuildContext context) {
    final questions = widget.proposal.questions;
    return ListView.builder(
      itemCount: questions.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.proposal.message),
              const SizedBox(height: 12),
              Text(
                'Umbral de aprobación: ${(_threshold * 100).round()}%',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Slider(
                value: _threshold,
                min: 0.3,
                max: 0.9,
                divisions: 12,
                label: '${(_threshold * 100).round()}%',
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _threshold = value),
              ),
              const Divider(),
            ],
          );
        }
        final question = questions[index - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ${question.prompt}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_kindLabel(question.kind)}'
                  '${question.topicName == null ? '' : ' · ${question.topicName}'}'
                  ' · Fuente: ${question.source}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                if (question.kind == 'respuesta_corta')
                  TextField(
                    controller: _controllerFor(question.id),
                    enabled: !_busy,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Tu respuesta',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) =>
                        _answers[question.id] = value,
                  )
                else
                  DropdownButton<String>(
                    value: _answers[question.id],
                    hint: const Text('Selecciona una opción'),
                    isExpanded: true,
                    items: [
                      for (final option in question.options)
                        DropdownMenuItem(
                          value: option,
                          child: Text(option),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() => _answers[question.id] = value);
                          },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResult(AssessmentResultDto result) {
    final prompts = {
      for (final question in widget.proposal.questions)
        question.id: question.prompt,
    };
    return ListView(
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              result.passed ? Icons.emoji_events_outlined : Icons.school_outlined,
            ),
            title: Text(result.message),
            subtitle: Text(
              '${result.correct}/${result.total} aciertos · '
              '${(result.score * 100).round()}%',
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final detail in result.details)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                detail.correct ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: detail.correct
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text(prompts[detail.questionId] ?? 'Pregunta'),
              subtitle: Text(
                '${detail.feedback}\nFuente: ${detail.source}',
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }

  Future<void> _grade() async {
    setState(() => _busy = true);
    try {
      final answers = [
        for (final question in widget.proposal.questions)
          AssessmentAnswerDto(
            questionId: question.id,
            answer: _answers[question.id] ?? '',
          ),
      ];
      final result = await ref
          .read(assessmentActionsProvider)
          .grade(
            widget.subjectId,
            widget.proposal.questions,
            answers,
            _threshold,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_describe(error))));
    }
  }
}

String _kindLabel(String kind) {
  switch (kind) {
    case 'opcion_multiple':
      return 'Opción múltiple';
    case 'verdadero_falso':
      return 'Verdadero o falso';
    case 'respuesta_corta':
      return 'Respuesta corta';
    default:
      return kind;
  }
}

String _formatDate(String iso) {
  final parsed = DateTime.tryParse(iso)?.toLocal();
  if (parsed == null) {
    return iso;
  }
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} '
      '${two(parsed.hour)}:${two(parsed.minute)}';
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
