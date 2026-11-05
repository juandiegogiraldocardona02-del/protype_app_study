import '../bridge/bridge.dart';

export '../bridge/bridge.dart' show ProfileDto, SubjectDto;

abstract class StudyRepository {
  Future<List<ProfileDto>> listProfiles();

  Future<ProfileDto> createProfile(String name);

  Future<ProfileDto> renameProfile(int id, String name);

  Future<void> deleteProfile(int id);

  Future<List<SubjectDto>> listSubjects(int profileId);

  Future<SubjectDto> createSubject(int profileId, String name, String color);

  Future<SubjectDto> updateSubject(int id, String name, String color);

  Future<void> deleteSubject(int id);
}
