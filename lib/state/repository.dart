import '../bridge/bridge.dart';

export '../bridge/bridge.dart'
    show
        AvailabilityDayDto,
        DocumentDto,
        FlashcardDto,
        FlashcardProposalDto,
        ImportOutcomeDto,
        MasteryOverviewDto,
        PlanProposalDto,
        PlanSettingsDto,
        PlannedSessionDto,
        ProfileDto,
        ReplanResultDto,
        ReviewResultDto,
        SessionDto,
        SubjectDto,
        TopicDto;

abstract class StudyRepository {
  Future<List<ProfileDto>> listProfiles();

  Future<ProfileDto> createProfile(String name);

  Future<ProfileDto> renameProfile(int id, String name);

  Future<void> deleteProfile(int id);

  Future<List<SubjectDto>> listSubjects(int profileId);

  Future<SubjectDto> createSubject(int profileId, String name, String color);

  Future<SubjectDto> updateSubject(int id, String name, String color);

  Future<void> deleteSubject(int id);

  Future<List<DocumentDto>> listDocuments(int subjectId);

  Future<ImportOutcomeDto> importDocument(int subjectId, String path);

  Future<void> deleteDocument(int id);

  Future<bool> ocrAvailable();

  Future<List<TopicDto>> listTopics(int subjectId);

  Future<TopicDto> createTopic(int subjectId, String name, double difficulty);

  Future<TopicDto> updateTopic(int id, String name, double difficulty);

  Future<void> deleteTopic(int id);

  Future<PlanSettingsDto> getPlanSettings(int subjectId);

  Future<PlanSettingsDto> savePlanSettings(
    int subjectId,
    int sessionMinutes,
    int startHour,
    String deadline,
    List<AvailabilityDayDto> availability,
  );

  Future<PlanProposalDto> previewPlan(int subjectId);

  Future<int> savePlan(int subjectId, List<PlannedSessionDto> sessions);

  Future<List<SessionDto>> listSessions(
    int profileId,
    int? subjectId,
    String start,
    String end,
  );

  Future<void> setSessionState(int id, String state);

  Future<ReplanResultDto> replanSubject(int subjectId);

  Future<int> revertReplan(int subjectId);

  Future<List<FlashcardDto>> listFlashcards(int subjectId);

  Future<FlashcardDto> createFlashcard(
    int topicId,
    String question,
    String answer,
  );

  Future<FlashcardDto> updateFlashcard(
    int id,
    String question,
    String answer,
  );

  Future<void> deleteFlashcard(int id);

  Future<List<FlashcardDto>> listDueFlashcards(int subjectId);

  Future<ReviewResultDto> reviewFlashcard(int id, int quality);

  Future<List<FlashcardProposalDto>> previewFlashcards(int subjectId);

  Future<int> saveFlashcards(
    int subjectId,
    List<FlashcardProposalDto> proposals,
  );

  Future<List<MasteryOverviewDto>> listMastery(int subjectId);
}
