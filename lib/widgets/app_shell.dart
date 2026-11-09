import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/assistant_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/subjects_screen.dart';
import '../state/providers.dart';
import 'profile_switcher.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_Destination> _destinations = [
  _Destination('Inicio', Icons.home_outlined, Icons.home),
  _Destination('Mis materias', Icons.menu_book_outlined, Icons.menu_book),
  _Destination(
    'Calendario',
    Icons.calendar_month_outlined,
    Icons.calendar_month,
  ),
  _Destination('Biblioteca', Icons.folder_outlined, Icons.folder),
  _Destination('Estadísticas', Icons.bar_chart_outlined, Icons.bar_chart),
  _Destination('Asistente IA', Icons.smart_toy_outlined, Icons.smart_toy),
  _Destination('Configuración', Icons.settings_outlined, Icons.settings),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navigationIndexProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final pages = <Widget>[
      const HomeScreen(),
      const SubjectsScreen(),
      const CalendarScreen(),
      const LibraryScreen(),
      const StatsScreen(),
      const AssistantScreen(),
      const SettingsScreen(embedded: true),
    ];

    final navigation = NavigationDrawer(
      selectedIndex: index,
      onDestinationSelected: (value) =>
          ref.read(navigationIndexProvider.notifier).select(value),
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.school_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Planificador',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Estudio offline',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _destinations.length; i++)
          NavigationDrawerDestination(
            icon: Icon(
              _destinations[i].icon,
              color: i == index
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            selectedIcon: Icon(
              _destinations[i].selectedIcon,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: Text(
              _destinations[i].label,
              style: TextStyle(
                fontWeight: i == index
                    ? FontWeight.w600
                    : FontWeight.w500,
                color: i == index
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Divider(height: 1),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.school_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              _destinations[index].label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          const ProfileSwitcher(),
        ],
      ),
      drawer: wide ? null : Drawer(child: SafeArea(child: navigation)),
      body: wide
          ? Row(
              children: [
                SizedBox(width: 280, child: navigation),
                const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(index: index, children: pages),
                ),
              ],
            )
          : IndexedStack(index: index, children: pages),
    );
  }
}
