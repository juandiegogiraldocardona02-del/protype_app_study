import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../state/repository.dart' show ProfileDto;
import '../widgets/backup_panel.dart';
import '../widgets/dialogs.dart';
import '../widgets/profile_avatar.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  Future<void> _pickAvatar(
    BuildContext context,
    WidgetRef ref,
    ProfileDto profile,
  ) async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Seleccionar foto de perfil',
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp', 'gif'],
    );
    if (result.isEmpty || !context.mounted) {
      return;
    }
    final path = result.first.path;
    if (path == null) {
      _snack(context, 'No se pudo obtener la ruta de la imagen.');
      return;
    }
    try {
      await ref.read(profileActionsProvider).setAvatar(profile.id, path);
      if (context.mounted) {
        _snack(context, 'Foto de perfil actualizada.');
      }
    } catch (error) {
      if (context.mounted) {
        _snack(context, 'No se pudo guardar la foto: $error');
      }
    }
  }

  Future<void> _removeAvatar(
    BuildContext context,
    WidgetRef ref,
    ProfileDto profile,
  ) async {
    try {
      await ref.read(profileActionsProvider).removeAvatar(profile.id);
      if (context.mounted) {
        _snack(context, 'Foto de perfil eliminada.');
      }
    } catch (error) {
      if (context.mounted) {
        _snack(context, 'No se pudo eliminar la foto: $error');
      }
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);
    final active = ref.watch(activeProfileProvider);

    final content = profilesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('No se pudieron cargar los perfiles: $error')),
      data: (profiles) {
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('Apariencia', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.palette_outlined),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Tema de la aplicación')),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_outlined),
                            label: Text('Sistema'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined),
                            label: Text('Claro'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined),
                            label: Text('Oscuro'),
                          ),
                        ],
                        selected: {
                          ref.watch(themeModeProvider).value ??
                              ThemeMode.system,
                        },
                        onSelectionChanged: (selection) {
                          ref
                              .read(themeModeProvider.notifier)
                              .select(selection.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Perfiles', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    final name = await showNameDialog(
                      context,
                      title: 'Nuevo perfil',
                      label: 'Nombre del perfil',
                      confirmLabel: 'Crear',
                    );
                    if (name == null || !context.mounted) {
                      return;
                    }
                    final created = await ref
                        .read(profileActionsProvider)
                        .create(name);
                    ref
                        .read(selectedProfileIdProvider.notifier)
                        .select(created.id);
                  },
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Nuevo perfil'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Los datos de cada perfil están aislados: documentos, '
              'asignaturas y estadísticas no se mezclan.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            for (final profile in profiles)
              Card(
                child: ListTile(
                  leading: ProfileAvatar(
                    profileId: profile.id,
                    name: profile.name,
                    radius: 20,
                  ),
                  title: Text(profile.name),
                  subtitle: Text(
                    profile.id == active?.id ? 'Perfil activo' : 'Perfil local',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Acciones de ${profile.name}',
                    onSelected: (value) async {
                      if (value == 'select') {
                        ref
                            .read(selectedProfileIdProvider.notifier)
                            .select(profile.id);
                      } else if (value == 'photo') {
                        await _pickAvatar(context, ref, profile);
                      } else if (value == 'removePhoto') {
                        await _removeAvatar(context, ref, profile);
                      } else if (value == 'rename') {
                        final name = await showNameDialog(
                          context,
                          title: 'Renombrar perfil',
                          label: 'Nombre del perfil',
                          initialValue: profile.name,
                        );
                        if (name == null || !context.mounted) {
                          return;
                        }
                        await ref
                            .read(profileActionsProvider)
                            .rename(profile.id, name);
                      } else if (value == 'delete') {
                        if (profiles.length <= 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Debe existir al menos un perfil.'),
                            ),
                          );
                          return;
                        }
                        final confirmed = await showConfirmDialog(
                          context,
                          title: 'Eliminar perfil',
                          message:
                              '¿Eliminar «${profile.name}» y todas sus '
                              'asignaturas? Esta acción no se puede deshacer.',
                          confirmLabel: 'Eliminar',
                        );
                        if (!confirmed || !context.mounted) {
                          return;
                        }
                        await ref
                            .read(profileActionsProvider)
                            .delete(profile.id);
                      }
                    },
                    itemBuilder: (context) => [
                      if (profile.id != active?.id)
                        const PopupMenuItem(
                          value: 'select',
                          child: ListTile(
                            leading: Icon(Icons.check_circle_outline),
                            title: Text('Usar este perfil'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      const PopupMenuItem(
                        value: 'photo',
                        child: ListTile(
                          leading: Icon(Icons.photo_camera_outlined),
                          title: Text('Cambiar foto'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'removePhoto',
                        child: ListTile(
                          leading: Icon(Icons.hide_image_outlined),
                          title: Text('Quitar foto'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Renombrar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Eliminar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => ref
                      .read(selectedProfileIdProvider.notifier)
                      .select(profile.id),
                ),
              ),
            const SizedBox(height: 32),
            const BackupPanel(),
            const SizedBox(height: 32),
            Text('Acerca de', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.storage_outlined),
                    title: Text('Almacenamiento local'),
                    subtitle: Text('SQLite en el dispositivo, sin servidores.'),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.wifi_off),
                    title: Text('Funcionamiento offline'),
                    subtitle: Text(
                      'La app no realiza llamadas de red en tiempo de '
                      'ejecución.',
                    ),
                  ),
                  Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Versión 1.0.0 · Etapa E7'),
                    subtitle: Text(
                      'Perfiles, documentos, planificación, repaso, '
                      'gamificación, asistente local y copias de seguridad '
                      'verificables.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: content,
    );
  }
}
