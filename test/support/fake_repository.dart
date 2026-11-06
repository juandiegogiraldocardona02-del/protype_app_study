import 'package:study_planner/state/repository.dart';

class FakeStudyRepository implements StudyRepository {
  FakeStudyRepository();

  final Map<int, ProfileDto> _profiles = <int, ProfileDto>{};
  final Map<int, List<SubjectDto>> _subjects = <int, List<SubjectDto>>{};
  final Map<int, List<DocumentDto>> _documents = <int, List<DocumentDto>>{};
  final Map<int, List<TopicDto>> _topics = <int, List<TopicDto>>{};
  final Map<int, PlanSettingsDto> _settings = <int, PlanSettingsDto>{};
  final Map<int, SessionDto> _sessions = <int, SessionDto>{};
  int _nextProfileId = 1;
  int _nextSubjectId = 1;
  int _nextDocumentId = 1;
  int _nextTopicId = 1;
  int _nextSessionId = 1;
  bool ocrAvailableResult = false;

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
      _documents.remove(subject.id);
      _topics.remove(subject.id);
      _settings.remove(subject.id);
      _sessions.removeWhere((_, session) => session.subjectId == subject.id);
    }
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
    _documents.remove(id);
    _topics.remove(id);
    _settings.remove(id);
    _sessions.removeWhere((_, session) => session.subjectId == id);
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
    return List<DocumentDto>.of(
      _documents[subjectId] ?? const <DocumentDto>[],
    );
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
  Future<TopicDto> updateTopic(
    int id,
    String name,
    double difficulty,
  ) async {
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
      final start = DateTime(day.year, day.month, day.day, settings.startHour)
          .add(Duration(minutes: slot * settings.sessionMinutes));
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
  Future<int> savePlan(
    int subjectId,
    List<PlannedSessionDto> sessions,
  ) async {
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
}

String _iso(DateTime value) =>
    '${_dateOnly(value)}T'
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}:00';

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
