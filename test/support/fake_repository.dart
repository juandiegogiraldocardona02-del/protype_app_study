import 'package:study_planner/state/repository.dart';

class FakeStudyRepository implements StudyRepository {
  FakeStudyRepository();

  final Map<int, ProfileDto> _profiles = <int, ProfileDto>{};
  final Map<int, List<SubjectDto>> _subjects = <int, List<SubjectDto>>{};
  final Map<int, List<DocumentDto>> _documents = <int, List<DocumentDto>>{};
  final Map<int, List<TopicDto>> _topics = <int, List<TopicDto>>{};
  final Map<int, List<AssessmentDto>> _assessments =
      <int, List<AssessmentDto>>{};
  final Map<int, PlanSettingsDto> _settings = <int, PlanSettingsDto>{};
  final Map<int, SessionDto> _sessions = <int, SessionDto>{};
  final Map<int, FlashcardDto> _flashcards = <int, FlashcardDto>{};
  final Map<int, List<int>> _reviewQualities = <int, List<int>>{};
  final Map<int, XpConfigDto> _xpConfigs = <int, XpConfigDto>{};
  final Map<int, int> _xpTotals = <int, int>{};
  final Map<int, int> _currentStreaks = <int, int>{};
  final Map<int, int> _bestStreaks = <int, int>{};
  final Map<int, String> _lastStreakDates = <int, String>{};
  final Set<int> _xpSessions = <int>{};
  final Set<int> _xpMasteredTopics = <int>{};
  int _nextProfileId = 1;
  int _nextSubjectId = 1;
  int _nextDocumentId = 1;
  int _nextTopicId = 1;
  int _nextSessionId = 1;
  int _nextFlashcardId = 1;
  int _nextAssessmentId = 1;
  bool ocrAvailableResult = false;
  bool audioAvailableResult = false;
  AssessmentProposalDto? assessmentProposal;
  AssessmentResultDto? assessmentResult;
  AiStatusDto aiStatus = const AiStatusDto(
    available: true,
    modelPath: 'models/test.gguf',
    modelsDir: 'models',
    message: 'Modelo de prueba disponible.',
  );
  AssistantAnswerDto? assistantAnswer;
  int? lastAssistantSubjectId;
  String? lastAssistantQuestion;
  bool? lastAssistantDocumentsOnly;
  BackupCountsDto backupCounts = const BackupCountsDto(
    profiles: 1,
    subjects: 1,
    topics: 2,
    documents: 1,
    chunks: 3,
    sessions: 4,
    flashcards: 5,
    reviews: 6,
    assessments: 0,
    xpEntries: 2,
    changes: 3,
  );
  StudyPlanPreviewDto? studyPlanPreview;
  StudyPlanImportDto? studyPlanImportResult;
  BackupPreviewDto? backupPreview;
  BackupRestoreDto? backupRestoreResult;
  int? lastExportSubjectId;
  String? lastExportDirectory;
  int? lastImportProfileId;
  bool? lastImportOverwrite;
  String? lastBackupDirectory;
  String? lastInspectPath;
  bool? lastRestoreOverwrite;

  ProfileDto addProfile(String name) {
    final profile = ProfileDto(
      id: _nextProfileId++,
      name: name,
      configJson: '{}',
    );
    _profiles[profile.id] = profile;
    _subjects[profile.id] = <SubjectDto>[];
    return profile;
  }

  SubjectDto addSubject(int profileId, String name, String color) {
    final subject = SubjectDto(
      id: _nextSubjectId++,
      profileId: profileId,
      name: name,
      color: color,
      xpConfigJson: '{}',
    );
    _subjects.putIfAbsent(profileId, () => <SubjectDto>[]).add(subject);
    return subject;
  }

  @override
  Future<List<ProfileDto>> listProfiles() async {
    return _profiles.values.toList();
  }

  @override
  Future<ProfileDto> createProfile(String name) async {
    return addProfile(name.trim());
  }

  @override
  Future<ProfileDto> renameProfile(int id, String name) async {
    final current = _profiles[id];
    if (current == null) {
      throw StateError('perfil $id no encontrado');
    }
    final updated = ProfileDto(
      id: current.id,
      name: name.trim(),
      configJson: current.configJson,
    );
    _profiles[id] = updated;
    return updated;
  }

  @override
  Future<void> deleteProfile(int id) async {
    _profiles.remove(id);
    for (final subject in _subjects.remove(id) ?? const <SubjectDto>[]) {
      _removeSubjectData(subject.id);
    }
  }

  void _removeSubjectData(int subjectId) {
    _documents.remove(subjectId);
    final topics = _topics.remove(subjectId) ?? const <TopicDto>[];
    final topicIds = topics.map((topic) => topic.id).toSet();
    _flashcards.removeWhere((_, card) => topicIds.contains(card.topicId));
    _reviewQualities.removeWhere((topicId, _) => topicIds.contains(topicId));
    _settings.remove(subjectId);
    _assessments.remove(subjectId);
    _sessions.removeWhere((_, session) => session.subjectId == subjectId);
  }

  @override
  Future<List<SubjectDto>> listSubjects(int profileId) async {
    return List<SubjectDto>.of(_subjects[profileId] ?? const <SubjectDto>[]);
  }

  @override
  Future<SubjectDto> createSubject(
    int profileId,
    String name,
    String color,
  ) async {
    if (!_profiles.containsKey(profileId)) {
      throw StateError('perfil $profileId no encontrado');
    }
    return addSubject(profileId, name.trim(), color);
  }

  @override
  Future<SubjectDto> updateSubject(int id, String name, String color) async {
    for (final entry in _subjects.entries) {
      final index = entry.value.indexWhere((subject) => subject.id == id);
      if (index != -1) {
        final current = entry.value[index];
        final updated = SubjectDto(
          id: current.id,
          profileId: current.profileId,
          name: name.trim(),
          color: color,
          xpConfigJson: current.xpConfigJson,
        );
        entry.value[index] = updated;
        return updated;
      }
    }
    throw StateError('asignatura $id no encontrada');
  }

  @override
  Future<void> deleteSubject(int id) async {
    for (final subjects in _subjects.values) {
      subjects.removeWhere((subject) => subject.id == id);
    }
    _removeSubjectData(id);
  }

  DocumentDto addDocument(
    int subjectId, {
    String name = 'apuntes.txt',
    String kind = 'txt',
    int version = 1,
    int textChars = 120,
    String extractionStatus = 'ok',
  }) {
    final document = DocumentDto(
      id: _nextDocumentId++,
      subjectId: subjectId,
      name: name,
      localPath: '/tmp/$name',
      kind: kind,
      hash: 'hash-$name-$version',
      version: version,
      extractionStatus: extractionStatus,
      textChars: textChars,
    );
    _documents.putIfAbsent(subjectId, () => <DocumentDto>[]).add(document);
    return document;
  }

  @override
  Future<List<DocumentDto>> listDocuments(int subjectId) async {
    return List<DocumentDto>.of(_documents[subjectId] ?? const <DocumentDto>[]);
  }

  final Map<int, List<String>> _documentChunks = {};

  @override
  Future<List<String>> listDocumentChunks(int documentId) async {
    return List<String>.of(_documentChunks[documentId] ?? const <String>[]);
  }

  void addDocumentChunks(int documentId, List<String> chunks) {
    _documentChunks.putIfAbsent(documentId, () => <String>[]).addAll(chunks);
  }

  @override
  Future<ImportOutcomeDto> importDocument(int subjectId, String path) async {
    final name = path.split(RegExp(r'[\\/]')).last;
    final existing = (_documents[subjectId] ?? const <DocumentDto>[]).where(
      (document) => document.name == name && document.kind != 'pdf',
    );
    if (existing.isNotEmpty) {
      return ImportOutcomeDto(
        document: existing.first,
        duplicate: true,
        ocrUsed: false,
        message: 'El documento ya estaba importado.',
      );
    }
    final document = addDocument(subjectId, name: name);
    return ImportOutcomeDto(
      document: document,
      duplicate: false,
      ocrUsed: false,
      message: 'Importado.',
    );
  }

  @override
  Future<void> deleteDocument(int id) async {
    for (final documents in _documents.values) {
      documents.removeWhere((document) => document.id == id);
    }
  }

  @override
  Future<bool> ocrAvailable() async => ocrAvailableResult;

  @override
  Future<bool> audioAvailable() async => audioAvailableResult;

  @override
  Future<AssessmentProposalDto> generateAssessment(
    int subjectId,
    int maxQuestions,
  ) async {
    final configured = assessmentProposal;
    if (configured != null) {
      return configured;
    }
    final topics = _topics[subjectId] ?? const <TopicDto>[];
    final topic = topics.isEmpty ? null : topics.first;
    final questions = <AssessmentQuestionDto>[
      AssessmentQuestionDto(
        id: 1,
        kind: 'opcion_multiple',
        prompt: 'Completa la frase: «La célula es la unidad _____».',
        options: const ['estructural', 'química', 'eléctrica', 'numérica'],
        correctAnswer: 'estructural',
        explanation: 'La célula es la unidad estructural de la vida.',
        source: 'apuntes.txt',
        topicId: topic?.id,
        topicName: topic?.name,
      ),
      AssessmentQuestionDto(
        id: 2,
        kind: 'verdadero_falso',
        prompt: 'Indica si es verdadera o falsa: «La célula es la unidad de la vida».',
        options: const ['Verdadero', 'Falso'],
        correctAnswer: 'Verdadero',
        explanation: 'La afirmación es verdadera.',
        source: 'apuntes.txt',
        topicId: topic?.id,
        topicName: topic?.name,
      ),
      AssessmentQuestionDto(
        id: 3,
        kind: 'respuesta_corta',
        prompt: 'Define o explica: «célula»',
        options: const [],
        correctAnswer:
            'La célula es la unidad estructural y funcional de la vida.',
        explanation: 'Respuesta tomada de apuntes.',
        source: 'apuntes.txt',
        topicId: topic?.id,
        topicName: topic?.name,
      ),
    ];
    return AssessmentProposalDto(
      questions: questions.take(maxQuestions <= 0 ? 10 : maxQuestions).toList(),
      message: 'Se generaron preguntas de prueba.',
    );
  }

  @override
  Future<AssessmentResultDto> gradeAssessment(
    int subjectId,
    List<AssessmentQuestionDto> questions,
    List<AssessmentAnswerDto> answers,
    double threshold,
  ) async {
    final configured = assessmentResult;
    if (configured != null) {
      return configured;
    }
    final byId = {
      for (final answer in answers) answer.questionId: answer.answer,
    };
    final details = <AssessmentQuestionResultDto>[];
    var correct = 0;
    for (final question in questions) {
      final answer = byId[question.id]?.trim() ?? '';
      final isCorrect = question.kind == 'respuesta_corta'
          ? answer.isNotEmpty
          : answer == question.correctAnswer;
      if (isCorrect) {
        correct += 1;
      }
      details.add(
        AssessmentQuestionResultDto(
          questionId: question.id,
          correct: isCorrect,
          similarity: isCorrect ? 1 : 0,
          expected: question.correctAnswer,
          feedback: isCorrect ? 'Correcto.' : 'Revisa la respuesta esperada.',
          source: question.source,
        ),
      );
    }
    final total = questions.length;
    final score = total == 0 ? 0.0 : correct / total;
    final passed = score >= threshold;
    final assessment = AssessmentDto(
      id: _nextAssessmentId++,
      subjectId: subjectId,
      kind: 'cuestionario',
      score: score,
      date: _iso(DateTime.now()),
      correct: correct,
      total: total,
      threshold: threshold,
    );
    _assessments
        .putIfAbsent(subjectId, () => <AssessmentDto>[])
        .add(assessment);
    return AssessmentResultDto(
      assessmentId: assessment.id,
      score: score,
      correct: correct,
      total: total,
      passed: passed,
      message: passed ? 'Cuestionario aprobado.' : 'Cuestionario no aprobado.',
      details: details,
    );
  }

  @override
  Future<List<AssessmentDto>> listAssessments(int subjectId) async {
    return List<AssessmentDto>.of(
      _assessments[subjectId] ?? const <AssessmentDto>[],
    );
  }

  TopicDto addTopic(
    int subjectId, {
    String name = 'Tema',
    double difficulty = 1,
  }) {
    final topic = TopicDto(
      id: _nextTopicId++,
      subjectId: subjectId,
      name: name,
      difficulty: difficulty,
      mastery: 0,
    );
    _topics.putIfAbsent(subjectId, () => <TopicDto>[]).add(topic);
    return topic;
  }

  SessionDto addSession(
    int subjectId, {
    String topicName = 'Sesión de estudio',
    String start = '2026-02-02T08:00:00',
    int durationMin = 50,
    String state = 'pendiente',
  }) {
    final subject = _findSubject(subjectId);
    final session = SessionDto(
      id: _nextSessionId++,
      subjectId: subjectId,
      topicName: topicName,
      subjectName: subject?.name ?? 'Asignatura',
      subjectColor: subject?.color ?? '#4F46E5',
      start: start,
      durationMin: durationMin,
      state: state,
    );
    _sessions[session.id] = session;
    return session;
  }

  FlashcardDto addFlashcard(
    int topicId, {
    String question = '¿Pregunta?',
    String answer = 'Respuesta',
    String? nextReview,
    String origin = 'manual',
    int intervalDays = 0,
    int repetitions = 0,
    double easeFactor = 2.5,
    String? lastReview,
  }) {
    final topic = _findTopic(topicId);
    if (topic == null) {
      throw StateError('tema $topicId no encontrado');
    }
    final card = FlashcardDto(
      id: _nextFlashcardId++,
      topicId: topicId,
      topicName: topic.name,
      subjectId: topic.subjectId,
      question: question,
      answer: answer,
      intervalDays: intervalDays,
      repetitions: repetitions,
      easeFactor: easeFactor,
      nextReview: nextReview,
      lastReview: lastReview,
      origin: origin,
    );
    _flashcards[card.id] = card;
    return card;
  }

  PlanSettingsDto setPlanSettings(
    int subjectId, {
    int sessionMinutes = 50,
    int startHour = 8,
    String deadline = '2026-12-31',
    List<AvailabilityDayDto>? availability,
  }) {
    final settings = PlanSettingsDto(
      subjectId: subjectId,
      sessionMinutes: sessionMinutes,
      startHour: startHour,
      deadline: deadline,
      availability:
          availability ??
          [
            for (var weekday = 1; weekday <= 5; weekday++)
              AvailabilityDayDto(weekday: weekday, minutes: 120),
          ],
    );
    _settings[subjectId] = settings;
    return settings;
  }

  TopicDto? _findTopic(int topicId) {
    for (final topics in _topics.values) {
      for (final topic in topics) {
        if (topic.id == topicId) {
          return topic;
        }
      }
    }
    return null;
  }

  bool _isDue(FlashcardDto card) {
    final next = card.nextReview;
    if (next == null) {
      return true;
    }
    final parsed = DateTime.tryParse(next);
    return parsed == null || !parsed.isAfter(DateTime.now());
  }

  double _masteryFor(int topicId) {
    final qualities = _reviewQualities[topicId] ?? const <int>[];
    if (qualities.isEmpty) {
      return 0;
    }
    final recent = qualities.length > 5
        ? qualities.sublist(qualities.length - 5)
        : qualities;
    final average = recent.reduce((a, b) => a + b) / recent.length;
    return ((average / 5) * 0.6).clamp(0.0, 1.0);
  }

  void _updateTopicMastery(int topicId, double mastery) {
    for (final topics in _topics.values) {
      final index = topics.indexWhere((topic) => topic.id == topicId);
      if (index != -1) {
        final current = topics[index];
        topics[index] = TopicDto(
          id: current.id,
          subjectId: current.subjectId,
          name: current.name,
          difficulty: current.difficulty,
          mastery: mastery,
        );
        return;
      }
    }
  }

  SubjectDto? _findSubject(int subjectId) {
    for (final subjects in _subjects.values) {
      for (final subject in subjects) {
        if (subject.id == subjectId) {
          return subject;
        }
      }
    }
    return null;
  }

  SubjectDto? _findSubjectOfProfile(int profileId, int subjectId) {
    for (final subject in _subjects[profileId] ?? const <SubjectDto>[]) {
      if (subject.id == subjectId) {
        return subject;
      }
    }
    return null;
  }

  @override
  Future<List<TopicDto>> listTopics(int subjectId) async {
    return List<TopicDto>.of(_topics[subjectId] ?? const <TopicDto>[]);
  }

  @override
  Future<TopicDto> createTopic(
    int subjectId,
    String name,
    double difficulty,
  ) async {
    return addTopic(subjectId, name: name, difficulty: difficulty);
  }

  @override
  Future<TopicDto> updateTopic(int id, String name, double difficulty) async {
    for (final topics in _topics.values) {
      final index = topics.indexWhere((topic) => topic.id == id);
      if (index != -1) {
        final current = topics[index];
        final updated = TopicDto(
          id: current.id,
          subjectId: current.subjectId,
          name: name,
          difficulty: difficulty,
          mastery: current.mastery,
        );
        topics[index] = updated;
        return updated;
      }
    }
    throw StateError('tema $id no encontrado');
  }

  @override
  Future<void> deleteTopic(int id) async {
    for (final topics in _topics.values) {
      topics.removeWhere((topic) => topic.id == id);
    }
  }

  @override
  Future<PlanSettingsDto> getPlanSettings(int subjectId) async {
    return _settings[subjectId] ?? setPlanSettings(subjectId);
  }

  @override
  Future<PlanSettingsDto> savePlanSettings(
    int subjectId,
    int sessionMinutes,
    int startHour,
    String deadline,
    List<AvailabilityDayDto> availability,
  ) async {
    return setPlanSettings(
      subjectId,
      sessionMinutes: sessionMinutes,
      startHour: startHour,
      deadline: deadline,
      availability: availability,
    );
  }

  @override
  Future<PlanProposalDto> previewPlan(int subjectId) async {
    final settings = await getPlanSettings(subjectId);
    final topics = _topics[subjectId] ?? const <TopicDto>[];
    var day = DateTime.now().add(const Duration(days: 1));
    var slot = 0;
    final sessions = <PlannedSessionDto>[];
    for (final topic in topics) {
      while (day.weekday > 5) {
        day = DateTime(day.year, day.month, day.day + 1);
      }
      final start = DateTime(
        day.year,
        day.month,
        day.day,
        settings.startHour,
      ).add(Duration(minutes: slot * settings.sessionMinutes));
      sessions.add(
        PlannedSessionDto(
          topicId: topic.id,
          topicName: topic.name,
          start: _iso(start),
          durationMin: settings.sessionMinutes,
          state: 'pendiente',
        ),
      );
      slot += 1;
      if (slot >= 2) {
        slot = 0;
        day = DateTime(day.year, day.month, day.day + 1);
      }
    }
    final weekly = settings.availability.fold<int>(
      0,
      (total, item) => total + item.minutes,
    );
    return PlanProposalDto(
      sessions: sessions,
      totalMinutes: sessions.length * settings.sessionMinutes,
      weeklyMinutes: weekly,
      lastDate: sessions.isEmpty
          ? _dateOnly(day)
          : sessions.last.start.substring(0, 10),
    );
  }

  @override
  Future<int> savePlan(int subjectId, List<PlannedSessionDto> sessions) async {
    _sessions.removeWhere(
      (_, session) =>
          session.subjectId == subjectId && session.state != 'completada',
    );
    final subject = _findSubject(subjectId);
    for (final planned in sessions) {
      final session = SessionDto(
        id: _nextSessionId++,
        subjectId: subjectId,
        topicId: planned.topicId,
        topicName: planned.topicName,
        subjectName: subject?.name ?? 'Asignatura',
        subjectColor: subject?.color ?? '#4F46E5',
        start: planned.start,
        durationMin: planned.durationMin,
        state: 'pendiente',
      );
      _sessions[session.id] = session;
    }
    return sessions.length;
  }

  @override
  Future<List<SessionDto>> listSessions(
    int profileId,
    int? subjectId,
    String start,
    String end,
  ) async {
    final result = _sessions.values.where((session) {
      if (_findSubjectOfProfile(profileId, session.subjectId) == null) {
        return false;
      }
      if (subjectId != null && session.subjectId != subjectId) {
        return false;
      }
      return session.start.compareTo(start) >= 0 &&
          session.start.compareTo(end) < 0;
    }).toList()..sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  @override
  Future<void> setSessionState(int id, String state) async {
    final current = _sessions[id];
    if (current == null) {
      throw StateError('sesión $id no encontrada');
    }
    _sessions[id] = SessionDto(
      id: current.id,
      subjectId: current.subjectId,
      topicId: current.topicId,
      topicName: current.topicName,
      subjectName: current.subjectName,
      subjectColor: current.subjectColor,
      start: current.start,
      durationMin: current.durationMin,
      state: state,
      originalStart: current.originalStart,
    );
    if (state == 'completada' && _xpSessions.add(id)) {
      final config = xpConfigFor(current.subjectId);
      _addXp(_profileForSubject(current.subjectId), config.session);
      _recordStreak(_profileForSubject(current.subjectId));
    }
  }

  @override
  Future<ReplanResultDto> replanSubject(int subjectId) async {
    final pending = _sessions.values
        .where(
          (session) =>
              session.subjectId == subjectId && session.state != 'completada',
        )
        .toList();
    var day = DateTime.now().add(const Duration(days: 1));
    for (var index = 0; index < pending.length; index++) {
      final current = pending[index];
      final start = DateTime(day.year, day.month, day.day, 8 + index);
      _sessions[current.id] = SessionDto(
        id: current.id,
        subjectId: current.subjectId,
        topicId: current.topicId,
        topicName: current.topicName,
        subjectName: current.subjectName,
        subjectColor: current.subjectColor,
        start: _iso(start),
        durationMin: current.durationMin,
        state: 'replanificada',
        originalStart: current.originalStart ?? current.start,
      );
    }
    return ReplanResultDto(
      moved: pending.length,
      message: 'Se recolocaron ${pending.length} sesiones pendientes.',
    );
  }

  @override
  Future<int> revertReplan(int subjectId) async {
    var reverted = 0;
    for (final session in _sessions.values.toList()) {
      if (session.subjectId != subjectId || session.originalStart == null) {
        continue;
      }
      _sessions[session.id] = SessionDto(
        id: session.id,
        subjectId: session.subjectId,
        topicId: session.topicId,
        topicName: session.topicName,
        subjectName: session.subjectName,
        subjectColor: session.subjectColor,
        start: session.originalStart!,
        durationMin: session.durationMin,
        state: 'pendiente',
      );
      reverted += 1;
    }
    return reverted;
  }

  @override
  Future<List<FlashcardDto>> listFlashcards(int subjectId) async {
    return _flashcards.values
        .where((card) => card.subjectId == subjectId)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Future<FlashcardDto> createFlashcard(
    int topicId,
    String question,
    String answer,
  ) async {
    return addFlashcard(
      topicId,
      question: question.trim(),
      answer: answer.trim(),
    );
  }

  @override
  Future<FlashcardDto> updateFlashcard(
    int id,
    String question,
    String answer,
  ) async {
    final current = _flashcards[id];
    if (current == null) {
      throw StateError('tarjeta $id no encontrada');
    }
    final updated = FlashcardDto(
      id: current.id,
      topicId: current.topicId,
      topicName: current.topicName,
      subjectId: current.subjectId,
      question: question.trim(),
      answer: answer.trim(),
      intervalDays: current.intervalDays,
      repetitions: current.repetitions,
      easeFactor: current.easeFactor,
      nextReview: current.nextReview,
      lastReview: current.lastReview,
      origin: current.origin,
    );
    _flashcards[id] = updated;
    return updated;
  }

  @override
  Future<void> deleteFlashcard(int id) async {
    _flashcards.remove(id);
  }

  @override
  Future<List<FlashcardDto>> listDueFlashcards(int subjectId) async {
    return _flashcards.values
        .where((card) => card.subjectId == subjectId && _isDue(card))
        .toList()
      ..sort((a, b) {
        final first = a.nextReview ?? '';
        final second = b.nextReview ?? '';
        final byDate = first.compareTo(second);
        return byDate == 0 ? a.id.compareTo(b.id) : byDate;
      });
  }

  @override
  Future<ReviewResultDto> reviewFlashcard(int id, int quality) async {
    final current = _flashcards[id];
    if (current == null) {
      throw StateError('tarjeta $id no encontrada');
    }
    final repetitions = quality < 3 ? 0 : current.repetitions + 1;
    final interval = quality < 3
        ? 1
        : current.repetitions == 0
        ? 1
        : current.repetitions == 1
        ? 6
        : (current.intervalDays * current.easeFactor).round().clamp(1, 3650);
    final delta = quality.toDouble();
    final ease =
        (current.easeFactor + (0.1 - (5 - delta) * (0.08 + (5 - delta) * 0.02)))
            .clamp(1.3, 3.0);
    final now = DateTime.now();
    final updated = FlashcardDto(
      id: current.id,
      topicId: current.topicId,
      topicName: current.topicName,
      subjectId: current.subjectId,
      question: current.question,
      answer: current.answer,
      intervalDays: interval,
      repetitions: repetitions,
      easeFactor: ease,
      nextReview: _iso(now.add(Duration(days: interval))),
      lastReview: _iso(now),
      origin: current.origin,
    );
    _flashcards[id] = updated;
    _reviewQualities.putIfAbsent(current.topicId, () => <int>[]).add(quality);
    final mastery = _masteryFor(current.topicId);
    _updateTopicMastery(current.topicId, mastery);
    final profileId = _profileForSubject(current.subjectId);
    _recordStreak(profileId);
    if (mastery >= 0.8 && _xpMasteredTopics.add(current.topicId)) {
      _addXp(profileId, xpConfigFor(current.subjectId).masterTopic);
    }
    return ReviewResultDto(
      flashcard: updated,
      quality: quality,
      mastery: mastery,
      message: 'Repaso registrado.',
    );
  }

  @override
  Future<List<FlashcardProposalDto>> previewFlashcards(int subjectId) async {
    final topics = _topics[subjectId] ?? const <TopicDto>[];
    return [
      for (final topic in topics)
        FlashcardProposalDto(
          topicId: topic.id,
          topicName: topic.name,
          question: '¿Qué debes recordar sobre «${topic.name}»?',
          answer: 'Revisa el contenido de «${topic.name}» en la asignatura.',
        ),
    ];
  }

  @override
  Future<int> saveFlashcards(
    int subjectId,
    List<FlashcardProposalDto> proposals,
  ) async {
    for (final proposal in proposals) {
      addFlashcard(
        proposal.topicId,
        question: proposal.question,
        answer: proposal.answer,
        origin: 'auto',
      );
    }
    return proposals.length;
  }

  @override
  Future<List<MasteryOverviewDto>> listMastery(int subjectId) async {
    final topics = _topics[subjectId] ?? const <TopicDto>[];
    return [
      for (final topic in topics)
        MasteryOverviewDto(
          topicId: topic.id,
          topicName: topic.name,
          mastery: _masteryFor(topic.id),
          dueCards: _flashcards.values
              .where((card) => card.topicId == topic.id && _isDue(card))
              .length,
          reviews: _reviewQualities[topic.id]?.length ?? 0,
        ),
    ];
  }

  static const XpConfigDto _defaultXpConfig = XpConfigDto(
    readSection: 10,
    task: 20,
    quizPassed: 30,
    session: 15,
    assessment: 50,
    streak7D: 100,
    masterTopic: 150,
  );

  XpConfigDto xpConfigFor(int subjectId) =>
      _xpConfigs[subjectId] ?? _defaultXpConfig;

  int xpTotalForProfile(int profileId) => _xpTotals[profileId] ?? 0;

  void seedGamification(
    int profileId, {
    int xp = 0,
    int currentStreak = 0,
    int bestStreak = 0,
  }) {
    _xpTotals[profileId] = xp;
    _currentStreaks[profileId] = currentStreak;
    _bestStreaks[profileId] = bestStreak;
    if (currentStreak > 0) {
      _lastStreakDates[profileId] = _dateOnly(DateTime.now());
    }
  }

  @override
  Future<XpConfigDto> getXpConfig(int subjectId) async =>
      xpConfigFor(subjectId);

  @override
  Future<XpConfigDto> saveXpConfig(int subjectId, XpConfigDto config) async {
    _xpConfigs[subjectId] = config;
    return config;
  }

  @override
  Future<GamificationSummaryDto> getGamificationSummary(int profileId) async {
    final total = xpTotalForProfile(profileId);
    var level = 1;
    var remaining = total;
    var needed = 100;
    while (remaining >= needed) {
      remaining -= needed;
      level++;
      needed += 100;
    }

    final today = _dateOnly(DateTime.now());
    final lastDate = _lastStreakDates[profileId];
    final current = lastDate == today ? (_currentStreaks[profileId] ?? 0) : 0;
    final best = _bestStreaks[profileId] ?? 0;
    final reviews = _reviewQualities.values.fold<int>(
      0,
      (sum, qualities) => sum + qualities.length,
    );
    final subjects = _subjects[profileId] ?? const <SubjectDto>[];
    final subjectIds = subjects.map((subject) => subject.id).toSet();
    final completedSessions = _sessions.values
        .where(
          (session) =>
              session.state == 'completada' &&
              subjectIds.contains(session.subjectId),
        )
        .length;
    final masteredTopics = [
      for (final entry in _topics.entries)
        if (subjectIds.contains(entry.key))
          ...entry.value.where((topic) => _masteryFor(topic.id) >= 0.8),
    ].length;

    return GamificationSummaryDto(
      profileId: profileId,
      totalXp: total,
      level: level,
      xpInLevel: remaining,
      xpForNextLevel: needed,
      currentStreak: current,
      bestStreak: best,
      freezeEnabled: false,
      badges: [
        BadgeDto(
          code: 'primer_repaso',
          title: 'Primer repaso',
          description: 'Repasa tu primera tarjeta.',
          earned: reviews > 0,
        ),
        BadgeDto(
          code: 'primera_sesion',
          title: 'Primera sesión',
          description: 'Completa una sesión de estudio.',
          earned: completedSessions > 0,
        ),
        BadgeDto(
          code: 'racha_7',
          title: 'Racha de 7 días',
          description: 'Estudia durante 7 días seguidos.',
          earned: best >= 7,
        ),
        BadgeDto(
          code: 'nivel_5',
          title: 'Nivel 5',
          description: 'Alcanza el nivel 5.',
          earned: level >= 5,
        ),
        BadgeDto(
          code: 'tema_dominado',
          title: 'Tema dominado',
          description: 'Domina un tema por completo.',
          earned: masteredTopics > 0,
        ),
        BadgeDto(
          code: 'diez_repasos',
          title: 'Diez repasos',
          description: 'Acumula diez repasos.',
          earned: reviews >= 10,
        ),
      ],
    );
  }

  @override
  Future<AiStatusDto> getAiStatus() async => aiStatus;

  @override
  Future<AssistantAnswerDto> askAssistant(
    int subjectId,
    String question,
    bool documentsOnly,
  ) async {
    lastAssistantSubjectId = subjectId;
    lastAssistantQuestion = question;
    lastAssistantDocumentsOnly = documentsOnly;
    final configured = assistantAnswer;
    if (configured != null) {
      return configured;
    }
    if (documentsOnly && (_documents[subjectId] ?? const []).isEmpty) {
      return const AssistantAnswerDto(
        answer:
            'No encontré esa información en los documentos de la asignatura.',
        origin: 'documentos',
        sources: [],
      );
    }
    return AssistantAnswerDto(
      answer: 'Respuesta de prueba para «$question».',
      origin: documentsOnly ? 'documentos' : 'general',
      sources: documentsOnly
          ? const [
              AssistantSourceDto(
                label: 'apuntes.txt · Tema 1',
                excerpt: 'Fragmento de prueba tomado de los apuntes.',
              ),
            ]
          : const [],
    );
  }

  @override
  Future<ExportResultDto> exportStudyPlan(
    int subjectId,
    String directory,
  ) async {
    lastExportSubjectId = subjectId;
    lastExportDirectory = directory;
    final subject = _findSubject(subjectId);
    return ExportResultDto(
      path: '$directory/${subject?.name ?? 'asignatura'}.studyplan',
      bytes: 2048,
      checksum: 'sha256-prueba',
      counts: backupCounts,
      message: 'Asignatura exportada.',
    );
  }

  @override
  Future<StudyPlanPreviewDto> inspectStudyPlan(
    String path,
    int profileId,
  ) async {
    lastInspectPath = path;
    return studyPlanPreview ??
        StudyPlanPreviewDto(
          subjectName: 'Asignatura importada',
          profileName: _profiles[profileId]?.name ?? 'Perfil',
          counts: backupCounts,
          conflict: false,
          message: 'Listo para importar.',
        );
  }

  @override
  Future<StudyPlanImportDto> importStudyPlan(
    String path,
    int profileId,
    bool overwrite,
  ) async {
    lastInspectPath = path;
    lastImportProfileId = profileId;
    lastImportOverwrite = overwrite;
    final configured = studyPlanImportResult;
    if (configured != null) {
      return configured;
    }
    final created = addSubject(profileId, 'Asignatura importada', '#4F46E5');
    return StudyPlanImportDto(
      subjectId: created.id,
      subjectName: created.name,
      profileId: profileId,
      counts: backupCounts,
      requiresConfirmation: false,
      message: 'Asignatura importada correctamente.',
    );
  }

  @override
  Future<ExportResultDto> exportBackup(String directory) async {
    lastBackupDirectory = directory;
    return ExportResultDto(
      path: '$directory/copia-global.studybackup',
      bytes: 4096,
      checksum: 'sha256-copia',
      counts: backupCounts,
      message: 'Copia global exportada.',
    );
  }

  @override
  Future<BackupPreviewDto> inspectBackup(String path) async {
    lastInspectPath = path;
    return backupPreview ??
        BackupPreviewDto(
          profileNames: _profiles.values
              .map((profile) => profile.name)
              .toList(),
          counts: backupCounts,
          conflict: false,
          message: 'Listo para restaurar la copia global.',
        );
  }

  @override
  Future<BackupRestoreDto> restoreBackup(String path, bool overwrite) async {
    lastInspectPath = path;
    lastRestoreOverwrite = overwrite;
    final configured = backupRestoreResult;
    if (configured != null) {
      return configured;
    }
    return BackupRestoreDto(
      counts: backupCounts,
      requiresConfirmation: false,
      message: 'Copia global restaurada correctamente.',
    );
  }

  int _profileForSubject(int subjectId) {
    for (final entry in _subjects.entries) {
      if (entry.value.any((subject) => subject.id == subjectId)) {
        return entry.key;
      }
    }
    throw StateError('materia $subjectId no encontrada');
  }

  void _addXp(int profileId, int amount) {
    _xpTotals[profileId] = xpTotalForProfile(profileId) + amount;
  }

  void _recordStreak(int profileId) {
    final today = _dateOnly(DateTime.now());
    final last = _lastStreakDates[profileId];
    if (last == today) {
      return;
    }
    final yesterday = _dateOnly(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final current = last == yesterday
        ? (_currentStreaks[profileId] ?? 0) + 1
        : 1;
    _currentStreaks[profileId] = current;
    _lastStreakDates[profileId] = today;
    if (current > (_bestStreaks[profileId] ?? 0)) {
      _bestStreaks[profileId] = current;
    }
    if (current % 7 == 0) {
      final subjects = _subjects[profileId] ?? const <SubjectDto>[];
      if (subjects.isNotEmpty) {
        _addXp(profileId, xpConfigFor(subjects.first.id).streak7D);
      }
    }
  }
}

String _iso(DateTime value) =>
    '${_dateOnly(value)}T'
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}:00';

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
