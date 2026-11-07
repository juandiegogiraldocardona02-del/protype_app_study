import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart';
import 'dialogs.dart';

class SubjectProgressPanel extends ConsumerWidget {
  const SubjectProgressPanel({super.key, required this.subject});

  final SubjectDto subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mastery = ref.watch(masteryProvider(subject.id));
    final due = ref.watch(dueFlashcardsProvider(subject.id));
    final cards = ref.watch(flashcardsProvider(subject.id));
    final xp = ref.watch(xpConfigProvider(subject.id));
    final topics = ref.watch(topicsProvider(subject.id)).asData?.value;
    final dueItems = due.asData?.value ?? const <FlashcardDto>[];
    final allCards = cards.asData?.value ?? const <FlashcardDto>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Dominio por tema',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        mastery.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Text('No se pudo cargar el dominio: $error'),
          data: (items) {
            if (items.isEmpty) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.insights_outlined),
                  title: const Text('Sin temas todavía'),
                  subtitle: const Text(
                    'Añade temas en la Agenda para medir tu dominio y crear '
                    'tarjetas de repaso.',
                  ),
                ),
              );
            }
            final low = items
                .where(
                  (item) =>
                      item.mastery < 0.5 &&
                      (item.reviews > 0 || item.dueCards > 0),
                )
                .map((item) => item.topicName)
                .toList();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    for (final item in items)
                      _MasteryRow(
                        name: item.topicName,
                        mastery: item.mastery,
                        dueCards: item.dueCards,
                        reviews: item.reviews,
                      ),
                    if (low.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sugerencia: repasa ${low.join(', ')}.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text('Flashcards', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: topics == null || topics.isEmpty
                  ? null
                  : () => _addCard(context, ref, topics),
              icon: const Icon(Icons.add),
              label: const Text('Añadir tarjeta'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dueItems.length} pendientes hoy · '
                  '${allCards.length} en total',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  dueItems.isEmpty
                      ? 'No hay tarjetas pendientes. Vuelve mañana o añade '
                            'nuevas tarjetas.'
                      : 'Repasa las tarjetas programadas para hoy con el '
                            'algoritmo SM-2.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: dueItems.isEmpty
                          ? null
                          : () => _review(context, ref, dueItems),
                      icon: const Icon(Icons.play_arrow_outlined),
                      label: Text('Repasar (${dueItems.length})'),
                    ),
                    OutlinedButton.icon(
                      onPressed: topics == null || topics.isEmpty
                          ? null
                          : () => _generate(context, ref),
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Generar desde documentos'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        cards.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) =>
              Text('No se pudieron cargar las tarjetas: $error'),
          data: (items) {
            if (items.isEmpty) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.style_outlined),
                  title: Text('Aún no hay tarjetas'),
                  subtitle: Text(
                    'Crea una manualmente o genera propuestas a partir de tus '
                    'documentos.',
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final card in items)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.style_outlined),
                      title: Text(card.question),
                      subtitle: Text(
                        '${card.topicName} · '
                        '${card.nextReview == null ? 'pendiente' : 'próxima ${_formatNext(card.nextReview!)}'}'
                        '${card.origin == 'auto' ? ' · generada' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar tarjeta',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: topics == null || topics.isEmpty
                                ? null
                                : () => _editCard(context, ref, topics, card),
                          ),
                          IconButton(
                            tooltip: 'Eliminar tarjeta',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteCard(context, ref, card),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Text(
              'XP por actividad',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: xp.asData?.value == null
                  ? null
                  : () => _editXp(context, ref, xp.asData!.value),
              icon: const Icon(Icons.tune_outlined),
              label: const Text('Configurar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        xp.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) =>
              Text('No se pudo cargar la configuración: $error'),
          data: (config) => Card(
            child: ListTile(
              leading: const Icon(Icons.bolt_outlined),
              title: const Text('Valores actuales'),
              subtitle: Text(
                'Sección ${config.readSection} · Tarea ${config.task} · '
                'Cuestionario ${config.quizPassed} · Sesión ${config.session} · '
                'Evaluación ${config.assessment} · Racha 7 d '
                '${config.streak7D} · Tema dominado ${config.masterTopic}',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _editXp(
    BuildContext context,
    WidgetRef ref,
    XpConfigDto current,
  ) async {
    final result = await showDialog<XpConfigDto>(
      context: context,
      builder: (context) => _XpConfigDialog(initial: current),
    );
    if (result == null) {
      return;
    }
    try {
      await ref
          .read(gamificationActionsProvider)
          .saveXpConfig(subject.id, result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Configuración guardada. Solo afecta a actividades futuras.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _addCard(
    BuildContext context,
    WidgetRef ref,
    List<TopicDto> topics,
  ) async {
    final result = await showFlashcardDialog(context, topics: topics);
    if (result == null) {
      return;
    }
    try {
      await ref
          .read(flashcardActionsProvider)
          .create(subject.id, result.topicId, result.question, result.answer);
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _editCard(
    BuildContext context,
    WidgetRef ref,
    List<TopicDto> topics,
    FlashcardDto card,
  ) async {
    final result = await showFlashcardDialog(
      context,
      topics: topics
          .where((topic) => topic.id == card.topicId)
          .toList(growable: false),
      initialTopicId: card.topicId,
      initialQuestion: card.question,
      initialAnswer: card.answer,
      title: 'Editar tarjeta',
    );
    if (result == null) {
      return;
    }
    try {
      await ref
          .read(flashcardActionsProvider)
          .update(subject.id, card.id, result.question, result.answer);
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _deleteCard(
    BuildContext context,
    WidgetRef ref,
    FlashcardDto card,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar tarjeta',
      message:
          '¿Eliminar «${card.question}»? Su historial de repasos también '
          'se eliminará.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(flashcardActionsProvider).delete(subject.id, card.id);
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    try {
      final proposals = await ref
          .read(flashcardActionsProvider)
          .preview(subject.id);
      if (!context.mounted) {
        return;
      }
      if (proposals.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay temas para generar tarjetas.')),
        );
        return;
      }
      final chosen = await _showProposalDialog(context, proposals);
      if (chosen == null || chosen.isEmpty || !context.mounted) {
        return;
      }
      final count = await ref
          .read(flashcardActionsProvider)
          .save(subject.id, chosen);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Se guardaron $count tarjetas.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        _showError(context, error);
      }
    }
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    List<FlashcardDto> cards,
  ) async {
    final reviewed = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ReviewDialog(
        subjectId: subject.id,
        cards: List<FlashcardDto>.of(cards),
      ),
    );
    if (reviewed != null && reviewed > 0 && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Repasaste $reviewed tarjetas.')));
    }
  }

  void _showError(BuildContext context, Object error) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_describe(error))));
  }
}

class _XpConfigDialog extends StatefulWidget {
  const _XpConfigDialog({required this.initial});

  final XpConfigDto initial;

  @override
  State<_XpConfigDialog> createState() => _XpConfigDialogState();
}

class _XpConfigDialogState extends State<_XpConfigDialog> {
  late final TextEditingController _readSection = TextEditingController(
    text: '${widget.initial.readSection}',
  );
  late final TextEditingController _task = TextEditingController(
    text: '${widget.initial.task}',
  );
  late final TextEditingController _quizPassed = TextEditingController(
    text: '${widget.initial.quizPassed}',
  );
  late final TextEditingController _session = TextEditingController(
    text: '${widget.initial.session}',
  );
  late final TextEditingController _assessment = TextEditingController(
    text: '${widget.initial.assessment}',
  );
  late final TextEditingController _streak7D = TextEditingController(
    text: '${widget.initial.streak7D}',
  );
  late final TextEditingController _masterTopic = TextEditingController(
    text: '${widget.initial.masterTopic}',
  );
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _readSection,
      _task,
      _quizPassed,
      _session,
      _assessment,
      _streak7D,
      _masterTopic,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _parse(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < 0 || value > 10000) {
      return null;
    }
    return value;
  }

  void _save() {
    final values = <int?>[
      _parse(_readSection),
      _parse(_task),
      _parse(_quizPassed),
      _parse(_session),
      _parse(_assessment),
      _parse(_streak7D),
      _parse(_masterTopic),
    ];
    if (values.contains(null)) {
      setState(() {
        _error = 'Usa números enteros entre 0 y 10000.';
      });
      return;
    }
    Navigator.of(context).pop(
      XpConfigDto(
        readSection: values[0]!,
        task: values[1]!,
        quizPassed: values[2]!,
        session: values[3]!,
        assessment: values[4]!,
        streak7D: values[5]!,
        masterTopic: values[6]!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('XP por actividad'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field('Leer sección', _readSection),
              _field('Completar tarea', _task),
              _field('Cuestionario aprobado', _quizPassed),
              _field('Sesión completada', _session),
              _field('Evaluación', _assessment),
              _field('Racha de 7 días', _streak7D),
              _field('Dominar un tema', _masterTopic),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _MasteryRow extends StatelessWidget {
  const _MasteryRow({
    required this.name,
    required this.mastery,
    required this.dueCards,
    required this.reviews,
  });

  final String name;
  final double mastery;
  final int dueCards;
  final int reviews;

  @override
  Widget build(BuildContext context) {
    final percent = (mastery * 100).round();
    final color = mastery < 0.5
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name)),
              if (mastery < 0.5 && (reviews > 0 || dueCards > 0))
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.lightbulb_outline, size: 18),
                ),
              Text('$percent%'),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: mastery.clamp(0.0, 1.0),
              minHeight: 8,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$dueCards pendientes · $reviews repasos',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

Future<List<FlashcardProposalDto>?> _showProposalDialog(
  BuildContext context,
  List<FlashcardProposalDto> proposals,
) {
  return showDialog<List<FlashcardProposalDto>>(
    context: context,
    builder: (context) => _ProposalDialog(proposals: proposals),
  );
}

class _ProposalDialog extends StatefulWidget {
  const _ProposalDialog({required this.proposals});

  final List<FlashcardProposalDto> proposals;

  @override
  State<_ProposalDialog> createState() => _ProposalDialogState();
}

class _ProposalDialogState extends State<_ProposalDialog> {
  late final List<bool> _included = List<bool>.filled(
    widget.proposals.length,
    true,
  );

  @override
  Widget build(BuildContext context) {
    final chosen = <FlashcardProposalDto>[
      for (var i = 0; i < _included.length; i++)
        if (_included[i]) widget.proposals[i],
    ];
    return AlertDialog(
      title: const Text('Tarjetas propuestas'),
      content: SizedBox(
        width: 560,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${chosen.length} de ${widget.proposals.length} seleccionadas',
            ),
            const SizedBox(height: 4),
            const Text(
              'Revisa el contenido y descarta las tarjetas que no te sirvan.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: widget.proposals.length,
                itemBuilder: (context, index) {
                  final proposal = widget.proposals[index];
                  return CheckboxListTile(
                    dense: true,
                    value: _included[index],
                    onChanged: (value) =>
                        setState(() => _included[index] = value ?? false),
                    title: Text(proposal.question),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(proposal.answer),
                        const SizedBox(height: 2),
                        Text(
                          proposal.source == null
                              ? 'Sin fuente en documentos: revísala antes de guardar.'
                              : 'Fuente: ${proposal.source}',
                          style: TextStyle(
                            fontSize: 11,
                            color: proposal.source == null
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop(chosen),
          child: Text('Guardar (${chosen.length})'),
        ),
      ],
    );
  }
}

class _ReviewDialog extends ConsumerStatefulWidget {
  const _ReviewDialog({required this.subjectId, required this.cards});

  final int subjectId;
  final List<FlashcardDto> cards;

  @override
  ConsumerState<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends ConsumerState<_ReviewDialog> {
  int _index = 0;
  int _reviewed = 0;
  bool _revealed = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.cards[_index];
    return AlertDialog(
      title: Text('Repaso ${_index + 1}/${widget.cards.length}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.topicName,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Text(
                card.question,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              if (_revealed)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(card.answer),
                )
              else
                const Text(
                  'Piensa la respuesta y luego descúbrela.',
                  style: TextStyle(fontSize: 12),
                ),
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
      actions: _revealed
          ? [
              Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: _busy ? null : () => _answer(1),
                    child: const Text('Otra vez'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _answer(3),
                    child: const Text('Difícil'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _answer(4),
                    child: const Text('Bien'),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : () => _answer(5),
                    child: const Text('Fácil'),
                  ),
                ],
              ),
            ]
          : [
              TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Salir'),
              ),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _revealed = true),
                child: const Text('Mostrar respuesta'),
              ),
            ],
    );
  }

  Future<void> _answer(int quality) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(flashcardActionsProvider)
          .review(widget.subjectId, widget.cards[_index].id, quality);
      if (!mounted) {
        return;
      }
      final reviewed = _reviewed + 1;
      if (_index + 1 >= widget.cards.length) {
        Navigator.of(context).pop(reviewed);
        return;
      }
      setState(() {
        _reviewed = reviewed;
        _index += 1;
        _revealed = false;
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

String _formatNext(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return iso;
  }
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(parsed.day)}/${two(parsed.month)}';
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
