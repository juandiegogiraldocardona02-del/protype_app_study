import '../bridge/bridge.dart' as rust;
import 'repository.dart';

class RustStudyRepository implements StudyRepository {
  @override
  Future<List<ProfileDto>> listProfiles() => rust.listProfiles();

  @override
  Future<ProfileDto> createProfile(String name) =>
      rust.createProfile(name: name);

  @override
  Future<ProfileDto> renameProfile(int id, String name) =>
      rust.renameProfile(id: id, name: name);

  @override
  Future<void> deleteProfile(int id) => rust.deleteProfile(id: id);

  @override
  Future<List<SubjectDto>> listSubjects(int profileId) =>
      rust.listSubjects(profileId: profileId);

  @override
  Future<SubjectDto> createSubject(int profileId, String name, String color) =>
      rust.createSubject(profileId: profileId, name: name, color: color);

  @override
  Future<SubjectDto> updateSubject(int id, String name, String color) =>
      rust.updateSubject(id: id, name: name, color: color);

  @override
  Future<void> deleteSubject(int id) => rust.deleteSubject(id: id);

  @override
  Future<List<DocumentDto>> listDocuments(int subjectId) =>
      rust.listDocuments(subjectId: subjectId);

  @override
  Future<ImportOutcomeDto> importDocument(int subjectId, String path) =>
      rust.importDocument(subjectId: subjectId, path: path);

  @override
  Future<void> deleteDocument(int id) => rust.deleteDocument(id: id);

  @override
  Future<bool> ocrAvailable() => rust.ocrAvailable();

  @override
  Future<List<TopicDto>> listTopics(int subjectId) =>
      rust.listTopics(subjectId: subjectId);

  @override
  Future<TopicDto> createTopic(int subjectId, String name, double difficulty) =>
      rust.createTopic(
        subjectId: subjectId,
        name: name,
        difficulty: difficulty,
      );

  @override
  Future<TopicDto> updateTopic(int id, String name, double difficulty) =>
      rust.updateTopic(id: id, name: name, difficulty: difficulty);

  @override
  Future<void> deleteTopic(int id) => rust.deleteTopic(id: id);

  @override
  Future<PlanSettingsDto> getPlanSettings(int subjectId) =>
      rust.getPlanSettings(subjectId: subjectId);

  @override
  Future<PlanSettingsDto> savePlanSettings(
    int subjectId,
    int sessionMinutes,
    int startHour,
    String deadline,
    List<AvailabilityDayDto> availability,
  ) => rust.savePlanSettings(
    subjectId: subjectId,
    sessionMinutes: sessionMinutes,
    startHour: startHour,
    deadline: deadline,
    availability: availability,
  );

  @override
  Future<PlanProposalDto> previewPlan(int subjectId) =>
      rust.previewPlan(subjectId: subjectId);

  @override
  Future<int> savePlan(int subjectId, List<PlannedSessionDto> sessions) =>
      rust.savePlan(subjectId: subjectId, sessions: sessions);

  @override
  Future<List<SessionDto>> listSessions(
    int profileId,
    int? subjectId,
    String start,
    String end,
  ) => rust.listSessions(
    profileId: profileId,
    subjectId: subjectId,
    start: start,
    end: end,
  );

  @override
  Future<void> setSessionState(int id, String state) =>
      rust.setSessionState(id: id, state: state);

  @override
  Future<ReplanResultDto> replanSubject(int subjectId) =>
      rust.replanSubject(subjectId: subjectId);

  @override
  Future<int> revertReplan(int subjectId) =>
      rust.revertReplan(subjectId: subjectId);

  @override
  Future<List<FlashcardDto>> listFlashcards(int subjectId) =>
      rust.listFlashcards(subjectId: subjectId);

  @override
  Future<FlashcardDto> createFlashcard(
    int topicId,
    String question,
    String answer,
  ) => rust.createFlashcard(
    topicId: topicId,
    question: question,
    answer: answer,
  );

  @override
  Future<FlashcardDto> updateFlashcard(
    int id,
    String question,
    String answer,
  ) => rust.updateFlashcard(id: id, question: question, answer: answer);

  @override
  Future<void> deleteFlashcard(int id) => rust.deleteFlashcard(id: id);

  @override
  Future<List<FlashcardDto>> listDueFlashcards(int subjectId) =>
      rust.listDueFlashcards(subjectId: subjectId);

  @override
  Future<ReviewResultDto> reviewFlashcard(int id, int quality) =>
      rust.reviewFlashcard(id: id, quality: quality);

  @override
  Future<List<FlashcardProposalDto>> previewFlashcards(int subjectId) =>
      rust.previewFlashcards(subjectId: subjectId);

  @override
  Future<int> saveFlashcards(
    int subjectId,
    List<FlashcardProposalDto> proposals,
  ) => rust.saveFlashcards(subjectId: subjectId, proposals: proposals);

  @override
  Future<List<MasteryOverviewDto>> listMastery(int subjectId) =>
      rust.listMastery(subjectId: subjectId);

  @override
  Future<XpConfigDto> getXpConfig(int subjectId) =>
      rust.getXpConfig(subjectId: subjectId);

  @override
  Future<XpConfigDto> saveXpConfig(int subjectId, XpConfigDto config) =>
      rust.saveXpConfig(subjectId: subjectId, config: config);

  @override
  Future<GamificationSummaryDto> getGamificationSummary(int profileId) =>
      rust.getGamificationSummary(profileId: profileId);
}
