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
