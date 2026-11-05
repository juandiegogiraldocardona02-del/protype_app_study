import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/settings_screen.dart';
import '../state/providers.dart';
import 'dialogs.dart';

class ProfileSwitcher extends ConsumerWidget {
  const ProfileSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider).asData?.value ?? const [];
    final active = ref.watch(activeProfileProvider);
    if (active == null) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<int>(
      tooltip: 'Cambiar de perfil',
      onSelected: (value) async {
        if (value == -1) {
          final name = await showNameDialog(
            context,
            title: 'Nuevo perfil',
            label: 'Nombre del perfil',
            confirmLabel: 'Crear',
          );
          if (name == null || !context.mounted) {
            return;
          }
          final created = await ref.read(profileActionsProvider).create(name);
          ref.read(selectedProfileIdProvider.notifier).select(created.id);
        } else if (value == -2) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          );
        } else {
          ref.read(selectedProfileIdProvider.notifier).select(value);
        }
      },
      itemBuilder: (context) => [
        for (final profile in profiles)
          CheckedPopupMenuItem<int>(
            value: profile.id,
            checked: profile.id == active.id,
            child: Text(profile.name),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<int>(
          value: -1,
          child: ListTile(
            leading: Icon(Icons.person_add_alt_1),
            title: Text('Nuevo perfil'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem<int>(
          value: -2,
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Gestionar perfiles'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              child: Text(
                active.name.isEmpty ? '?' : active.name[0].toUpperCase(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(active.name, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
