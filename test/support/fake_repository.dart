import 'package:study_planner/state/repository.dart';

class FakeStudyRepository implements StudyRepository {
  FakeStudyRepository();

  final Map<int, ProfileDto> _profiles = <int, ProfileDto>{};
  final Map<int, List<SubjectDto>> _subjects = <int, List<SubjectDto>>{};
  int _nextProfileId = 1;
  int _nextSubjectId = 1;

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
    _subjects.remove(id);
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
  }
}
