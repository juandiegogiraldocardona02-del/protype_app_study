import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart' show NoteDto;
import '../widgets/dialogs.dart';
import '../widgets/empty_state.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    NoteDto? note,
  }) async {
    final profile = ref.read(activeProfileProvider);
    if (profile == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorScreen(profileId: profile.id, note: note),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    NoteDto note,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar apunte',
      message: '¿Eliminar «${note.title}»? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await ref.read(noteActionsProvider).delete(note.id);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el apunte: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    if (profile == null) {
      return const EmptyState(
        icon: Icons.edit_note_outlined,
        title: 'Apuntes',
        message: 'Crea un perfil para empezar a tomar apuntes.',
      );
    }
    final notes = ref.watch(notesProvider(profile.id));

    return notes.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'No se pudieron cargar los apuntes',
        message: error.toString(),
      ),
      data: (items) {
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.edit_note_outlined,
            title: 'Todavía no tienes apuntes',
            message:
                'Crea apuntes con un título, texto normal y puntos. Usa * o - '
                'al inicio de una línea para crear una lista.',
            action: FilledButton.icon(
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Crear apunte'),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          children: <Widget>[
            _NotesHeader(onCreate: () => _openEditor(context, ref)),
            const SizedBox(height: 16),
            for (final note in items) ...<Widget>[
              _NoteCard(
                note: note,
                onOpen: () => _openEditor(context, ref, note: note),
                onDelete: () => _delete(context, ref, note),
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _NotesHeader extends StatelessWidget {
  const _NotesHeader({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.edit_note,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Apuntes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Título, texto normal y puntos. Escribe * o - al inicio de '
                    'una línea para crear una lista.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo apunte'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onOpen,
    required this.onDelete,
  });

  final NoteDto note;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snippet = note.content.trim();
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(
            Icons.sticky_note_2_outlined,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (snippet.isNotEmpty)
              Text(
                snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 2),
            Text(
              _formatUpdated(note.updatedAt),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Acciones del apunte',
          onSelected: (value) {
            if (value == 'open') {
              onOpen();
            } else if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'open',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Editar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_outline),
                title: Text('Eliminar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, required this.profileId, this.note});

  final int profileId;
  final NoteDto? note;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _body = TextEditingController(text: widget.note?.content ?? '');
    _body.addListener(_refreshPreview);
    _title.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _body.removeListener(_refreshPreview);
    _title.removeListener(_refreshPreview);
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  void _insertBullet() {
    final text = _body.text;
    final selection = _body.selection;
    final cursor = selection.isValid ? selection.baseOffset : text.length;
    var lineStart = 0;
    if (cursor > 0) {
      final previousBreak = text.lastIndexOf('\n', cursor - 1);
      if (previousBreak != -1) {
        lineStart = previousBreak + 1;
      }
    }
    final nextBreak = text.indexOf('\n', lineStart);
    final lineEnd = nextBreak == -1 ? text.length : nextBreak;
    final line = text.substring(lineStart, lineEnd);
    if (line.trimLeft().startsWith('* ') || line.trimLeft().startsWith('- ')) {
      _body.selection = TextSelection.collapsed(offset: lineEnd);
      return;
    }
    final updated = text.replaceRange(lineStart, lineStart, '* ');
    _body.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: cursor + 2),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título no puede estar vacío.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final actions = ref.read(noteActionsProvider);
      if (widget.note == null) {
        await actions.create(widget.profileId, title, _body.text);
      } else {
        await actions.update(widget.note!.id, title, _body.text);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar el apunte: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final note = widget.note;
    if (note == null) {
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Eliminar apunte',
      message: '¿Eliminar «${note.title}»? Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) {
      return;
    }
    try {
      await ref.read(noteActionsProvider).delete(note.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el apunte: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.note == null ? 'Nuevo apunte' : 'Editar apunte'),
        actions: <Widget>[
          if (widget.note != null)
            IconButton(
              onPressed: _saving ? null : _delete,
              tooltip: 'Eliminar apunte',
              icon: const Icon(Icons.delete_outline),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Guardar'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          TextField(
            controller: _title,
            autofocus: widget.note == null,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Ejemplo: Saludo',
              prefixIcon: Icon(Icons.edit_note_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Flexible(
                child: Text(
                  'Usa * o - al inicio de una línea para crear un punto. '
                  'El resto de líneas se muestran como texto normal.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _insertBullet,
                icon: const Icon(Icons.format_list_bulleted, size: 18),
                label: const Text('Añadir punto'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 8,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Contenido',
              hintText: 'saluda\n* acercarse\n* presentarse\n* hablar',
              prefixIcon: Icon(Icons.notes),
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Icon(
                Icons.visibility_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Vista previa',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _NotePreview(title: _title.text, content: _body.text),
        ],
      ),
    );
  }
}

class _NotePreview extends StatelessWidget {
  const _NotePreview({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmedTitle = title.trim();
    final lines = content.split('\n');
    final widgets = <Widget>[];
    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      if (trimmed == '*' ||
          trimmed == '-' ||
          trimmed.startsWith('* ') ||
          trimmed.startsWith('- ')) {
        final text = trimmed.length <= 2 ? '' : trimmed.substring(2).trimLeft();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text.isEmpty ? '…' : text,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(trimmed, style: theme.textTheme.bodyMedium),
          ),
        );
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (trimmedTitle.isNotEmpty) ...<Widget>[
              Text(
                trimmedTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (widgets.isEmpty)
              Text(
                'La vista previa aparecerá aquí mientras escribes.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...widgets,
          ],
        ),
      ),
    );
  }
}

String _formatUpdated(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) {
    return iso;
  }
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
