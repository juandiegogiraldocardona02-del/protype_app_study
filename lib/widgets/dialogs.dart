import 'package:flutter/material.dart';

import '../bridge/bridge.dart';

const List<String> subjectPalette = <String>[
  '#4F46E5',
  '#0891B2',
  '#059669',
  '#D97706',
  '#DC2626',
  '#DB2777',
  '#7C3AED',
  '#475569',
];

Color colorFromHex(String hex) {
  final normalized = hex.replaceFirst('#', '');
  final value = int.tryParse(normalized, radix: 16) ?? 0x4F46E5;
  return Color(0xFF000000 | value);
}

Future<String?> showNameDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initialValue = '',
  String confirmLabel = 'Guardar',
}) {
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) {
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final value = controller.text.trim();
            if (value.isEmpty) {
              setState(() => errorText = 'El nombre no puede estar vacío');
              return;
            }
            Navigator.of(context).pop(value);
          }

          return AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: label,
                errorText: errorText,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(onPressed: submit, child: Text(confirmLabel)),
            ],
          );
        },
      );
    },
  );
}

typedef SubjectFormResult = ({String name, String color});Future<SubjectFormResult?> showSubjectDialog(
  BuildContext context, {
  String initialName = '',
  String initialColor = '#4F46E5',
  String title = 'Nueva asignatura',
}) {
  final controller = TextEditingController(text: initialName);
  var selectedColor = initialColor;
  return showDialog<SubjectFormResult>(
    context: context,
    builder: (context) {
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final value = controller.text.trim();
            if (value.isEmpty) {
              setState(() => errorText = 'El nombre no puede estar vacío');
              return;
            }
            Navigator.of(context).pop((name: value, color: selectedColor));
          }

          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la asignatura',
                      errorText: errorText,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 20),
                  Text('Color', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final hex in subjectPalette)
                        _ColorDot(
                          hex: hex,
                          selected: selectedColor == hex,
                          onTap: () => setState(() => selectedColor = hex),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(onPressed: submit, child: const Text('Guardar')),
            ],
          );
        },
      );
    },
  );
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Color $hex',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colorFromHex(hex),
            shape: BoxShape.circle,
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface,
                    width: 3,
                  )
                : null,
          ),
          child: selected
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

typedef TopicFormResult = ({String name, double difficulty});

Future<TopicFormResult?> showTopicDialog(
  BuildContext context, {
  String initialName = '',
  double initialDifficulty = 1,
  String title = 'Nuevo tema',
}) {
  final controller = TextEditingController(text: initialName);
  var difficulty = initialDifficulty.clamp(1, 5).toDouble();
  return showDialog<TopicFormResult>(
    context: context,
    builder: (context) {
      String? errorText;
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final value = controller.text.trim();
            if (value.isEmpty) {
              setState(() => errorText = 'El nombre no puede estar vacío');
              return;
            }
            Navigator.of(context).pop((name: value, difficulty: difficulty));
          }

          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Nombre del tema',
                      errorText: errorText,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dificultad: ${difficulty.round()} de 5',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Slider(
                    value: difficulty,
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: difficulty.round().toString(),
                    onChanged: (value) => setState(() => difficulty = value),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(onPressed: submit, child: const Text('Guardar')),
            ],
          );
        },
      );
    },
  );
}

typedef FlashcardFormResult = ({
  int topicId,
  String question,
  String answer,
});

Future<FlashcardFormResult?> showFlashcardDialog(
  BuildContext context, {
  required List<TopicDto> topics,
  int? initialTopicId,
  String initialQuestion = '',
  String initialAnswer = '',
  String title = 'Nueva tarjeta',
}) {
  if (topics.isEmpty) {
    return Future<FlashcardFormResult?>.value();
  }
  final questionController = TextEditingController(text: initialQuestion);
  final answerController = TextEditingController(text: initialAnswer);
  var topicId = initialTopicId != null &&
          topics.any((topic) => topic.id == initialTopicId)
      ? initialTopicId
      : topics.first.id;
  return showDialog<FlashcardFormResult>(
    context: context,
    builder: (context) {
      String? questionError;
      String? answerError;
      return StatefulBuilder(
        builder: (context, setState) {
          void submit() {
            final question = questionController.text.trim();
            final answer = answerController.text.trim();
            if (question.isEmpty || answer.isEmpty) {
              setState(() {
                questionError = question.isEmpty
                    ? 'La pregunta no puede estar vacía'
                    : null;
                answerError = answer.isEmpty
                    ? 'La respuesta no puede estar vacía'
                    : null;
              });
              return;
            }
            Navigator.of(context).pop((
              topicId: topicId,
              question: question,
              answer: answer,
            ));
          }

          return AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: topicId,
                      decoration: const InputDecoration(labelText: 'Tema'),
                      items: [
                        for (final topic in topics)
                          DropdownMenuItem<int>(
                            value: topic.id,
                            child: Text(topic.name),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => topicId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: questionController,
                      autofocus: true,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Pregunta',
                        errorText: questionError,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: answerController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Respuesta',
                        errorText: answerError,
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
              FilledButton(onPressed: submit, child: const Text('Guardar')),
            ],
          );
        },
      );
    },
  );
}

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
