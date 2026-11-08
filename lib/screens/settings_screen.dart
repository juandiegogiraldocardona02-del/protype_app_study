import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../widgets/backup_panel.dart';
import '../widgets/dialogs.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

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
                  leading: CircleAvatar(
                    child: Text(
                      profile.name.isEmpty
                          ? '?'
                          : profile.name[0].toUpperCase(),
                    ),
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
