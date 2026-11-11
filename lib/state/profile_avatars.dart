import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ProfileAvatars {
  const ProfileAvatars._();

  static const List<String> _extensions = <String>[
    'png',
    'jpg',
    'jpeg',
    'webp',
    'gif',
  ];

  static Future<Directory> _directory() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}avatars',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static File _fileFor(Directory directory, int profileId, String extension) {
    return File(
      '${directory.path}${Platform.pathSeparator}$profileId.$extension',
    );
  }

  static Future<String?> pathFor(int profileId) async {
    final directory = await _directory();
    for (final extension in _extensions) {
      final file = _fileFor(directory, profileId, extension);
      if (await file.exists()) {
        return file.path;
      }
    }
    return null;
  }

  static Future<void> remove(int profileId) async {
    final directory = await _directory();
    for (final extension in _extensions) {
      final file = _fileFor(directory, profileId, extension);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<String> save(int profileId, String sourcePath) async {
    final directory = await _directory();
    await remove(profileId);
    final source = File(sourcePath);
    final rawExtension = sourcePath.split('.').last.toLowerCase();
    final extension = _extensions.contains(rawExtension) ? rawExtension : 'png';
    final destination = _fileFor(directory, profileId, extension);
    await source.copy(destination.path);
    return destination.path;
  }
}
