import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repository.dart';

final repositoryProvider = Provider<StudyRepository>((ref) {
  throw UnimplementedError(
    'repositoryProvider debe sobrescribirse en el arranque de la app',
  );
});

final profilesProvider = FutureProvider<List<ProfileDto>>((ref) async {
  return ref.watch(repositoryProvider).listProfiles();
});

class SelectedProfileId extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedProfileIdProvider = NotifierProvider<SelectedProfileId, int?>(
  SelectedProfileId.new,
);

final activeProfileProvider = Provider<ProfileDto?>((ref) {
  final profiles = ref.watch(profilesProvider).asData?.value;
  if (profiles == null || profiles.isEmpty) {
    return null;
  }
  final selectedId = ref.watch(selectedProfileIdProvider);
  if (selectedId != null) {
    for (final profile in profiles) {
      if (profile.id == selectedId) {
        return profile;
      }
    }
  }
  return profiles.first;
});

final subjectsProvider = FutureProvider.family<List<SubjectDto>, int>((
  ref,
  profileId,
) {
  return ref.watch(repositoryProvider).listSubjects(profileId);
});

final documentsProvider = FutureProvider.family<List<DocumentDto>, int>((
  ref,
  subjectId,
) {
  return ref.watch(repositoryProvider).listDocuments(subjectId);
});

final topicsProvider = FutureProvider.family<List<TopicDto>, int>((
  ref,
  subjectId,
) {
  return ref.watch(repositoryProvider).listTopics(subjectId);
});

final planSettingsProvider = FutureProvider.family<PlanSettingsDto, int>((
  ref,
  subjectId,
) {
  return ref.watch(repositoryProvider).getPlanSettings(subjectId);
});

class SessionQuery {
  const SessionQuery({
    required this.profileId,
    required this.subjectId,
    required this.start,
    required this.end,
  });

  final int profileId;
  final int? subjectId;
  final String start;
  final String end;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionQuery &&
          runtimeType == other.runtimeType &&
          profileId == other.profileId &&
          subjectId == other.subjectId &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(profileId, subjectId, start, end);
}

final sessionsProvider = FutureProvider.family<List<SessionDto>, SessionQuery>((
  ref,
  query,
) {
  return ref
      .watch(repositoryProvider)
      .listSessions(
        query.profileId,
        query.subjectId,
        query.start,
        query.end,
      );
});

class NavigationIndex extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final navigationIndexProvider = NotifierProvider<NavigationIndex, int>(
  NavigationIndex.new,
);

class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  Future<ProfileDto> create(String name) async {
    final created = await _repo.createProfile(name);
    _ref.invalidate(profilesProvider);
    return created;
  }

  Future<void> rename(int id, String name) async {
    await _repo.renameProfile(id, name);
    _ref.invalidate(profilesProvider);
  }

  Future<void> delete(int id) async {
    await _repo.deleteProfile(id);
    if (_ref.read(selectedProfileIdProvider) == id) {
      _ref.read(selectedProfileIdProvider.notifier).select(null);
    }
    _ref.invalidate(profilesProvider);
  }
}

final profileActionsProvider = Provider<ProfileActions>(
  (ref) => ProfileActions(ref),
);

class SubjectActions {
  SubjectActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  Future<SubjectDto> create(int profileId, String name, String color) async {
    final created = await _repo.createSubject(profileId, name, color);
    _ref.invalidate(subjectsProvider(profileId));
    return created;
  }

  Future<void> update(int profileId, int id, String name, String color) async {
    await _repo.updateSubject(id, name, color);
    _ref.invalidate(subjectsProvider(profileId));
  }

  Future<void> delete(int profileId, int id) async {
    await _repo.deleteSubject(id);
    _ref.invalidate(subjectsProvider(profileId));
  }
}

final subjectActionsProvider = Provider<SubjectActions>(
  (ref) => SubjectActions(ref),
);

class DocumentActions {
  DocumentActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  Future<ImportOutcomeDto> import(int subjectId, String path) async {
    final outcome = await _repo.importDocument(subjectId, path);
    _ref.invalidate(documentsProvider(subjectId));
    return outcome;
  }

  Future<void> delete(int subjectId, int id) async {
    await _repo.deleteDocument(id);
    _ref.invalidate(documentsProvider(subjectId));
  }

  Future<bool> ocrAvailable() => _repo.ocrAvailable();
}

final documentActionsProvider = Provider<DocumentActions>(
  (ref) => DocumentActions(ref),
);

class TopicActions {
  TopicActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  Future<TopicDto> create(
    int subjectId,
    String name,
    double difficulty,
  ) async {
    final created = await _repo.createTopic(subjectId, name, difficulty);
    _ref.invalidate(topicsProvider(subjectId));
    return created;
  }

  Future<void> update(
    int subjectId,
    int id,
    String name,
    double difficulty,
  ) async {
    await _repo.updateTopic(id, name, difficulty);
    _ref.invalidate(topicsProvider(subjectId));
  }

  Future<void> delete(int subjectId, int id) async {
    await _repo.deleteTopic(id);
    _ref.invalidate(topicsProvider(subjectId));
  }
}

final topicActionsProvider = Provider<TopicActions>(
  (ref) => TopicActions(ref),
);

class PlanActions {
  PlanActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  Future<PlanSettingsDto> saveSettings(
    int subjectId,
    int sessionMinutes,
    int startHour,
    String deadline,
    List<AvailabilityDayDto> availability,
  ) async {
    final saved = await _repo.savePlanSettings(
      subjectId,
      sessionMinutes,
      startHour,
      deadline,
      availability,
    );
    _ref.invalidate(planSettingsProvider(subjectId));
    return saved;
  }

  Future<PlanProposalDto> preview(int subjectId) => _repo.previewPlan(subjectId);

  Future<int> save(int subjectId, List<PlannedSessionDto> sessions) async {
    final count = await _repo.savePlan(subjectId, sessions);
    _ref.invalidate(sessionsProvider);
    return count;
  }

  Future<void> setSessionState(int id, String state) async {
    await _repo.setSessionState(id, state);
    _ref.invalidate(sessionsProvider);
  }

  Future<ReplanResultDto> replan(int subjectId) async {
    final result = await _repo.replanSubject(subjectId);
    _ref.invalidate(sessionsProvider);
    return result;
  }

  Future<int> revert(int subjectId) async {
    final count = await _repo.revertReplan(subjectId);
    _ref.invalidate(sessionsProvider);
    return count;
  }
}

final planActionsProvider = Provider<PlanActions>((ref) => PlanActions(ref));
