import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'profile_avatars.dart';
import 'repository.dart';
import 'theme_store.dart';

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

class ThemeModeController extends AsyncNotifier<ThemeMode> {
  @override
  Future<ThemeMode> build() async {
    return await ThemeStore.load() ?? ThemeMode.system;
  }

  Future<void> select(ThemeMode mode) async {
    state = AsyncData(mode);
    await ThemeStore.save(mode);
  }
}

final themeModeProvider = AsyncNotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);

final profileAvatarProvider = FutureProvider.family<String?, int>((
  ref,
  profileId,
) {
  return ProfileAvatars.pathFor(profileId);
});

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

final notesProvider = FutureProvider.family<List<NoteDto>, int>((
  ref,
  profileId,
) {
  return ref.watch(repositoryProvider).listNotes(profileId);
});

final documentsProvider = FutureProvider.family<List<DocumentDto>, int>((
  ref,
  subjectId,
) {
  return ref.watch(repositoryProvider).listDocuments(subjectId);
});

final documentChunksProvider = FutureProvider.family<List<String>, int>((
  ref,
  documentId,
) {
  return ref.watch(repositoryProvider).listDocumentChunks(documentId);
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
      .listSessions(query.profileId, query.subjectId, query.start, query.end);
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
    await ProfileAvatars.remove(id);
    if (_ref.read(selectedProfileIdProvider) == id) {
      _ref.read(selectedProfileIdProvider.notifier).select(null);
    }
    _ref.invalidate(profilesProvider);
    _ref.invalidate(profileAvatarProvider(id));
  }

  Future<void> setAvatar(int id, String sourcePath) async {
    await ProfileAvatars.save(id, sourcePath);
    _ref.invalidate(profileAvatarProvider(id));
  }

  Future<void> removeAvatar(int id) async {
    await ProfileAvatars.remove(id);
    _ref.invalidate(profileAvatarProvider(id));
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

class NoteActions {
  NoteActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  Future<NoteDto> create(int profileId, String title, String content) async {
    final created = await _repo.createNote(profileId, title, content);
    _ref.invalidate(notesProvider);
    return created;
  }

  Future<void> update(int id, String title, String content) async {
    await _repo.updateNote(id, title, content);
    _ref.invalidate(notesProvider);
  }

  Future<void> delete(int id) async {
    await _repo.deleteNote(id);
    _ref.invalidate(notesProvider);
  }
}

final noteActionsProvider = Provider<NoteActions>((ref) => NoteActions(ref));

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

  Future<bool> audioAvailable() => _repo.audioAvailable();
}

final documentActionsProvider = Provider<DocumentActions>(
  (ref) => DocumentActions(ref),
);

class TopicActions {
  TopicActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  Future<TopicDto> create(int subjectId, String name, double difficulty) async {
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

final topicActionsProvider = Provider<TopicActions>((ref) => TopicActions(ref));

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

  Future<PlanProposalDto> preview(int subjectId) =>
      _repo.previewPlan(subjectId);

  Future<int> save(int subjectId, List<PlannedSessionDto> sessions) async {
    final count = await _repo.savePlan(subjectId, sessions);
    _ref.invalidate(sessionsProvider);
    return count;
  }

  Future<void> setSessionState(int id, String state) async {
    await _repo.setSessionState(id, state);
    _ref.invalidate(sessionsProvider);
    _ref.invalidate(masteryProvider);
    _ref.invalidate(topicsProvider);
    _ref.invalidate(gamificationProvider);
  }

  Future<void> setSessionDuration(int id, int durationMin) async {
    await _repo.updateSessionDuration(id, durationMin);
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

final flashcardsProvider = FutureProvider.family<List<FlashcardDto>, int>((
  ref,
  subjectId,
) {
  return ref.watch(repositoryProvider).listFlashcards(subjectId);
});

final dueFlashcardsProvider = FutureProvider.family<List<FlashcardDto>, int>((
  ref,
  subjectId,
) {
  return ref.watch(repositoryProvider).listDueFlashcards(subjectId);
});

final masteryProvider = FutureProvider.family<List<MasteryOverviewDto>, int>((
  ref,
  subjectId,
) {
  return ref.watch(repositoryProvider).listMastery(subjectId);
});

final assessmentsProvider = FutureProvider.family<List<AssessmentDto>, int>((
  ref,
  subjectId,
) {
  return ref.watch(repositoryProvider).listAssessments(subjectId);
});

final audioAvailableProvider = FutureProvider<bool>((ref) {
  return ref.watch(repositoryProvider).audioAvailable();
});

class AssessmentActions {
  AssessmentActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  Future<AssessmentProposalDto> generate(int subjectId, int maxQuestions) =>
      _repo.generateAssessment(subjectId, maxQuestions);

  Future<AssessmentResultDto> grade(
    int subjectId,
    List<AssessmentQuestionDto> questions,
    List<AssessmentAnswerDto> answers,
    double threshold,
  ) async {
    final result = await _repo.gradeAssessment(
      subjectId,
      questions,
      answers,
      threshold,
    );
    _ref.invalidate(assessmentsProvider(subjectId));
    _ref.invalidate(masteryProvider(subjectId));
    _ref.invalidate(topicsProvider(subjectId));
    _ref.invalidate(gamificationProvider);
    return result;
  }
}

final assessmentActionsProvider = Provider<AssessmentActions>(
  (ref) => AssessmentActions(ref),
);

class FlashcardActions {
  FlashcardActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  void _invalidate(int subjectId) {
    _ref.invalidate(flashcardsProvider(subjectId));
    _ref.invalidate(dueFlashcardsProvider(subjectId));
    _ref.invalidate(masteryProvider(subjectId));
    _ref.invalidate(topicsProvider(subjectId));
  }

  Future<FlashcardDto> create(
    int subjectId,
    int topicId,
    String question,
    String answer,
  ) async {
    final created = await _repo.createFlashcard(topicId, question, answer);
    _invalidate(subjectId);
    return created;
  }

  Future<FlashcardDto> update(
    int subjectId,
    int id,
    String question,
    String answer,
  ) async {
    final updated = await _repo.updateFlashcard(id, question, answer);
    _invalidate(subjectId);
    return updated;
  }

  Future<void> delete(int subjectId, int id) async {
    await _repo.deleteFlashcard(id);
    _invalidate(subjectId);
  }

  Future<List<FlashcardProposalDto>> preview(int subjectId) =>
      _repo.previewFlashcards(subjectId);

  Future<int> save(int subjectId, List<FlashcardProposalDto> proposals) async {
    final count = await _repo.saveFlashcards(subjectId, proposals);
    _invalidate(subjectId);
    return count;
  }

  Future<ReviewResultDto> review(int subjectId, int id, int quality) async {
    final result = await _repo.reviewFlashcard(id, quality);
    _invalidate(subjectId);
    _ref.invalidate(gamificationProvider);
    return result;
  }
}

final flashcardActionsProvider = Provider<FlashcardActions>(
  (ref) => FlashcardActions(ref),
);

final gamificationProvider = FutureProvider.family<GamificationSummaryDto, int>(
  (ref, profileId) {
    return ref.watch(repositoryProvider).getGamificationSummary(profileId);
  },
);

final xpConfigProvider = FutureProvider.family<XpConfigDto, int>((
  ref,
  subjectId,
) {
  return ref.watch(repositoryProvider).getXpConfig(subjectId);
});

class GamificationActions {
  GamificationActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  Future<XpConfigDto> saveXpConfig(int subjectId, XpConfigDto config) async {
    final saved = await _repo.saveXpConfig(subjectId, config);
    _ref.invalidate(xpConfigProvider(subjectId));
    return saved;
  }
}

final gamificationActionsProvider = Provider<GamificationActions>(
  (ref) => GamificationActions(ref),
);

final aiStatusProvider = FutureProvider<AiStatusDto>((ref) {
  return ref.watch(repositoryProvider).getAiStatus();
});

class AssistantActions {
  AssistantActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  Future<AssistantAnswerDto> ask(
    int subjectId,
    String question,
    bool documentsOnly,
  ) {
    return _repo.askAssistant(subjectId, question, documentsOnly);
  }
}

final assistantActionsProvider = Provider<AssistantActions>(
  (ref) => AssistantActions(ref),
);

class BackupActions {
  BackupActions(this._ref);

  final Ref _ref;

  StudyRepository get _repo => _ref.read(repositoryProvider);

  Future<ExportResultDto> exportStudyPlan(int subjectId, String directory) =>
      _repo.exportStudyPlan(subjectId, directory);

  Future<StudyPlanPreviewDto> inspectStudyPlan(String path, int profileId) =>
      _repo.inspectStudyPlan(path, profileId);

  Future<StudyPlanImportDto> importStudyPlan(
    String path,
    int profileId,
    bool overwrite,
  ) async {
    final result = await _repo.importStudyPlan(path, profileId, overwrite);
    if (!result.requiresConfirmation) {
      _ref.invalidate(subjectsProvider);
      _ref.invalidate(sessionsProvider);
    }
    return result;
  }

  Future<ExportResultDto> exportBackup(String directory) =>
      _repo.exportBackup(directory);

  Future<BackupPreviewDto> inspectBackup(String path) =>
      _repo.inspectBackup(path);

  Future<BackupRestoreDto> restoreBackup(String path, bool overwrite) async {
    final result = await _repo.restoreBackup(path, overwrite);
    if (!result.requiresConfirmation) {
      _ref.read(selectedProfileIdProvider.notifier).select(null);
      _invalidateAll();
    }
    return result;
  }

  void _invalidateAll() {
    _ref.invalidate(profilesProvider);
    _ref.invalidate(subjectsProvider);
    _ref.invalidate(documentsProvider);
    _ref.invalidate(topicsProvider);
    _ref.invalidate(planSettingsProvider);
    _ref.invalidate(sessionsProvider);
    _ref.invalidate(flashcardsProvider);
    _ref.invalidate(dueFlashcardsProvider);
    _ref.invalidate(masteryProvider);
    _ref.invalidate(assessmentsProvider);
    _ref.invalidate(gamificationProvider);
    _ref.invalidate(xpConfigProvider);
  }
}

final backupActionsProvider = Provider<BackupActions>(
  (ref) => BackupActions(ref),
);
