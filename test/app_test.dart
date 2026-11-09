import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/app.dart';
import 'package:study_planner/state/providers.dart';
import 'package:study_planner/state/repository.dart';

import 'support/fake_file_picker.dart';
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
    repository.addDocument(1, name: 'Tema 1.pdf', kind: 'pdf', textChars: 3200);
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

  testWidgets('añade un tema desde la agenda de la asignatura', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biología'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Añadir tema'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Mitocondrias');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('Mitocondrias'), findsOneWidget);
    expect((await repository.listTopics(1)), hasLength(1));
  });

  testWidgets('genera y corrige un cuestionario desde Evaluaciones', (
    tester,
  ) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.addTopic(1, name: 'La célula');
    repository.addDocument(1, name: 'Apuntes.txt', kind: 'txt');

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biología'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Evaluaciones'));
    await tester.pumpAndSettle();

    expect(find.text('Generar cuestionario'), findsOneWidget);
    await tester.tap(find.text('Generar cuestionario'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cuestionario (3 preguntas)'), findsOneWidget);
    await tester.tap(find.text('Corregir'));
    await tester.pumpAndSettle();

    expect(find.text('Resultado'), findsOneWidget);
    expect(find.textContaining('Cuestionario no aprobado'), findsOneWidget);
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('Historial'), findsOneWidget);
    expect(await repository.listAssessments(1), hasLength(1));
  });

  testWidgets('muestra la pestaña de música del área de estudio', (
    tester,
  ) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biología'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Música'));
    await tester.pumpAndSettle();

    expect(find.text('Escuchar con Spotify'), findsOneWidget);
    expect(find.text('YouTube para estudiar'), findsOneWidget);
    expect(find.text('Reproductor offline'), findsOneWidget);
  });

  testWidgets('muestra la pestaña de inicio de clase del área de estudio', (
    tester,
  ) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biología'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inicio de clase'));
    await tester.pumpAndSettle();

    expect(find.text('Abre el archivo para la clase'), findsOneWidget);
    expect(find.text('Abrir archivo'), findsOneWidget);
  });

  testWidgets('genera y guarda un plan desde la agenda', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.addTopic(1, name: 'La célula');
    repository.setPlanSettings(1);

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biología'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generar plan'));
    await tester.pumpAndSettle();
    expect(find.text('Vista previa del plan'), findsOneWidget);

    await tester.tap(find.textContaining('Guardar plan'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Plan guardado con'), findsOneWidget);
    final start = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String();
    final end = DateTime.now().add(const Duration(days: 60)).toIso8601String();
    final sessions = await repository.listSessions(1, 1, start, end);
    expect(sessions, hasLength(1));
  });

  testWidgets('el calendario muestra sesiones y permite completarlas', (
    tester,
  ) async {
    final now = DateTime.now();
    final start =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}T08:00:00';
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.addSession(1, topicName: 'La célula', start: start);

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Calendario').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Semana'));
    await tester.pumpAndSettle();

    expect(find.text('La célula'), findsOneWidget);
    await tester.tap(find.text('La célula'));
    await tester.pumpAndSettle();

    final end = now.add(const Duration(days: 1)).toIso8601String();
    final sessions = await repository.listSessions(
      1,
      1,
      '${start.substring(0, 10)}T00:00:00',
      end,
    );
    expect(sessions.single.state, 'completada');
  });

  testWidgets('añade una tarjeta manual desde Progreso', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.addTopic(1, name: 'La célula');

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biología'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progreso'));
    await tester.pumpAndSettle();

    expect(find.text('Dominio por tema'), findsOneWidget);
    await tester.tap(find.text('Añadir tarjeta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '¿Qué es la célula?');
    await tester.enterText(
      find.byType(TextField).at(1),
      'La unidad básica de la vida.',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Qué es la célula?'), findsOneWidget);
    expect(await repository.listFlashcards(1), hasLength(1));
  });

  testWidgets('repasa una tarjeta pendiente y actualiza el dominio', (
    tester,
  ) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    final topic = repository.addTopic(1, name: 'La célula');
    repository.addFlashcard(
      topic.id,
      question: '¿Qué es la mitocondria?',
      answer: 'La central energética de la célula.',
    );

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biología'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progreso'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Repasar (1)'));
    await tester.pumpAndSettle();
    expect(find.text('¿Qué es la mitocondria?'), findsWidgets);
    await tester.tap(find.text('Mostrar respuesta'));
    await tester.pumpAndSettle();
    expect(find.text('La central energética de la célula.'), findsOneWidget);
    await tester.tap(find.text('Bien'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Repasaste 1 tarjetas'), findsOneWidget);
    expect(await repository.listDueFlashcards(1), isEmpty);
    final mastery = await repository.listMastery(1);
    expect(mastery.single.mastery, greaterThan(0));
  });

  testWidgets('genera tarjetas propuestas desde los temas', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.addTopic(1, name: 'La célula');

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biología'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progreso'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Generar desde documentos'));
    await tester.pumpAndSettle();
    expect(find.text('Tarjetas propuestas'), findsOneWidget);
    await tester.tap(find.textContaining('Guardar ('));
    await tester.pumpAndSettle();

    expect(find.textContaining('Se guardaron 1 tarjetas'), findsOneWidget);
    expect(await repository.listFlashcards(1), hasLength(1));
  });

  testWidgets('el inicio muestra nivel y racha', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.seedGamification(1, xp: 250, currentStreak: 3, bestStreak: 5);

    await _pumpApp(tester, repository);

    expect(find.text('Nivel 2 · 250 XP'), findsOneWidget);
    expect(find.text('Racha 3 d'), findsOneWidget);
    expect(find.text('Mejor 5 d'), findsOneWidget);
  });

  testWidgets('las estadísticas resumen XP, nivel e insignias', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.seedGamification(1, xp: 100, currentStreak: 7, bestStreak: 7);

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();

    expect(find.text('Progreso de Ana'), findsOneWidget);
    expect(find.text('XP total'), findsOneWidget);
    expect(find.text('Insignias'), findsOneWidget);
    expect(find.text('Racha de 7 días'), findsOneWidget);
  });

  testWidgets('guarda la configuración de XP de la asignatura', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.addTopic(1, name: 'La célula');

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biología'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progreso'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Configurar'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Configurar'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '33');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Configuración guardada'), findsOneWidget);
    expect((await repository.getXpConfig(1)).readSection, 33);
  });

  testWidgets('el asistente avisa cuando no hay modelo local', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.aiStatus = const AiStatusDto(
      available: false,
      modelsDir: '/datos/models',
      message: 'No se encontró ningún modelo .gguf.',
    );

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Asistente IA').last);
    await tester.pumpAndSettle();

    expect(find.text('Modelo local no instalado'), findsOneWidget);
    expect(find.textContaining('/datos/models'), findsOneWidget);
  });

  testWidgets('el asistente responde citando los documentos', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    repository.addDocument(1, name: 'apuntes.txt');

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Asistente IA').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      '¿Qué función tiene la mitocondria?',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preguntar'));
    await tester.pumpAndSettle();

    expect(find.text('Fuente: documentos de la asignatura'), findsOneWidget);
    expect(find.text('apuntes.txt · Tema 1'), findsOneWidget);
    expect(
      find.textContaining('¿Qué función tiene la mitocondria?'),
      findsWidgets,
    );
    expect(repository.lastAssistantDocumentsOnly, isTrue);
  });

  testWidgets('el asistente permite usar conocimiento general', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Asistente IA').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '¿Qué es una célula?');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preguntar'));
    await tester.pumpAndSettle();

    expect(find.text('Conocimiento general del modelo'), findsOneWidget);
    expect(repository.lastAssistantDocumentsOnly, isFalse);
  });

  testWidgets('exporta una copia global desde configuración', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    final picker = FakeFilePicker()..directoryPath = r'C:\copias';
    FilePickerPlatform.instance = picker;

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Exportar copia global'));
    await tester.tap(find.text('Exportar copia global'));
    await tester.pumpAndSettle();

    expect(repository.lastBackupDirectory, r'C:\copias');
    expect(find.textContaining('Copia global exportada'), findsOneWidget);
  });

  testWidgets('restaura una copia global tras confirmar el reemplazo', (
    tester,
  ) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.backupPreview = const BackupPreviewDto(
      profileNames: ['Ana'],
      counts: BackupCountsDto(
        profiles: 1,
        subjects: 1,
        topics: 0,
        documents: 0,
        chunks: 0,
        sessions: 0,
        flashcards: 0,
        reviews: 0,
        assessments: 0,
        xpEntries: 0,
        changes: 0,
      ),
      conflict: true,
      message: 'Ya existen perfiles en este dispositivo.',
    );
    final picker = FakeFilePicker()
      ..addFile(r'C:\copias\copia-global.studybackup');
    FilePickerPlatform.instance = picker;

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restaurar copia global'));
    await tester.tap(find.text('Restaurar copia global'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Ya existen perfiles en este dispositivo.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reemplazar todo'));
    await tester.pumpAndSettle();

    expect(repository.lastRestoreOverwrite, isTrue);
    expect(find.textContaining('Copia global restaurada'), findsOneWidget);
  });

  testWidgets('importa una asignatura .studyplan en el perfil activo', (
    tester,
  ) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    final picker = FakeFilePicker()..addFile(r'C:\copias\Biologia.studyplan');
    FilePickerPlatform.instance = picker;

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Importar asignatura'));
    await tester.tap(find.text('Importar asignatura'));
    await tester.pumpAndSettle();

    expect(find.text('Importar asignatura'), findsWidgets);
    await tester.tap(find.text('Importar').last);
    await tester.pumpAndSettle();

    expect(repository.lastImportProfileId, 1);
    expect(repository.lastImportOverwrite, isFalse);
    expect(find.textContaining('Asignatura importada'), findsOneWidget);
    expect(await repository.listSubjects(1), hasLength(1));
  });

  testWidgets('exporta una asignatura desde su espacio', (tester) async {
    final repository = FakeStudyRepository()..addProfile('Ana');
    repository.addSubject(1, 'Biología', '#059669');
    final picker = FakeFilePicker()..directoryPath = r'C:\copias';
    FilePickerPlatform.instance = picker;

    await _pumpApp(tester, repository);
    await tester.tap(find.text('Mis materias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Biología'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Acciones de la asignatura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exportar .studyplan'));
    await tester.pumpAndSettle();

    expect(repository.lastExportSubjectId, 1);
    expect(repository.lastExportDirectory, r'C:\copias');
    expect(find.textContaining('Asignatura exportada'), findsOneWidget);
  });
}
