import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/app.dart';
import 'package:study_planner/state/providers.dart';

import 'support/fake_repository.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  FakeStudyRepository repository,
) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(repository)],
      child: const StudyPlannerApp(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el primer arranque pide crear un perfil', (tester) async {
    final repository = FakeStudyRepository();
    await _pumpApp(tester, repository);

    expect(find.text('Planificador de Estudios'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ana');
    await tester.tap(find.text('Comenzar'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Ana'), findsOneWidget);
    expect(find.text('Inicio'), findsWidgets);
  });

  testWidgets('crea una asignatura y la muestra en Mis materias', (
    tester,
  ) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    await _pumpApp(tester, repository);

    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Asignatura'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Matemáticas');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Matemáticas'), findsOneWidget);
  });

  testWidgets('el nombre vacío se rechaza en el formulario', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    await _pumpApp(tester, repository);

    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Asignatura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('El nombre no puede estar vacío'), findsOneWidget);
  });

  testWidgets('los datos se aíslan al cambiar de perfil', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Matemáticas', '#4F46E5');
    repository.addProfile('Luis');
    repository.addSubject(2, 'Historia', '#0891B2');

    await _pumpApp(tester, repository);

    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    expect(find.text('Matemáticas'), findsOneWidget);
    expect(find.text('Historia'), findsNothing);

    await tester.tap(find.byTooltip('Cambiar de perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckedPopupMenuItem<int>, 'Luis'));
    await tester.pumpAndSettle();

    expect(find.text('Historia'), findsOneWidget);
    expect(find.text('Matemáticas'), findsNothing);
  });

  testWidgets('no permite eliminar el único perfil', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    await _pumpApp(tester, repository);

    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Acciones de Ana'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Debe existir al menos un perfil.'), findsOneWidget);
    expect(find.text('Ana'), findsWidgets);
  });

  testWidgets('la biblioteca lista y filtra documentos de la asignatura', (
    tester,
  ) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.addDocument(
      1,
      name: 'Tema 1.pdf',
      kind: 'pdf',
      textChars: 3200,
    );
    repository.addDocument(1, name: 'Apuntes.txt', kind: 'txt');

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Biblioteca').first);
    await tester.pumpAndSettle();

    expect(find.text('Tema 1.pdf'), findsOneWidget);
    expect(find.text('Apuntes.txt'), findsOneWidget);

    await tester.tap(find.text('PDF'));
    await tester.pumpAndSettle();
    expect(find.text('Tema 1.pdf'), findsOneWidget);
    expect(find.text('Apuntes.txt'), findsNothing);
  });

  testWidgets('la biblioteca avisa de imágenes sin OCR', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.addDocument(
      1,
      name: 'Escaneo.png',
      kind: 'imagen',
      textChars: 0,
      extractionStatus: 'ocr_no_disponible',
    );

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Biblioteca').first);
    await tester.pumpAndSettle();

    expect(find.text('Escaneo.png'), findsOneWidget);
    expect(find.textContaining('sin OCR'), findsOneWidget);
  });

  testWidgets('elimina un documento tras confirmar', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.addDocument(1, name: 'Borrar.txt', kind: 'txt');

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Biblioteca').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Eliminar documento'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Borrar.txt'), findsNothing);
    expect(await repository.listDocuments(1), isEmpty);
  });
}
