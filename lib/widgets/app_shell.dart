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
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              Icon(
                Icons.school_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Planificador',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < _destinations.length; i++)
          NavigationDrawerDestination(
            icon: Icon(_destinations[i].icon),
            selectedIcon: Icon(_destinations[i].selectedIcon),
            label: Text(_destinations[i].label),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Divider(),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(_destinations[index].label)),
            const ProfileSwitcher(),
          ],
        ),
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
