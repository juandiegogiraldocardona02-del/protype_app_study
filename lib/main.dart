import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'bridge/bridge.dart';
import 'bridge/frb_generated.dart';
import 'state/providers.dart';
import 'state/rust_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await RustLib.init();
    final supportDirectory = await getApplicationSupportDirectory();
    final databasePath =
        '${supportDirectory.path}${Platform.pathSeparator}study_planner.sqlite';
    initializeDatabase(path: databasePath);
  } catch (error) {
    runApp(_StartupErrorApp(message: error.toString()));
    return;
  }

  runApp(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(RustStudyRepository())],
      child: const StudyPlannerApp(),
    ),
  );
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'No se pudo iniciar el núcleo local.',
                    style: TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  const Text(
                    'Comprueba que la aplicación tenga permiso de escritura en '
                    'su directorio de datos.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
