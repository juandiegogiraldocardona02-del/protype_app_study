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
}
