import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ThemeStore {
  const ThemeStore._();

  static const String _fileName = 'theme_mode.txt';

  static Future<File> _file() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<ThemeMode?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return null;
      }
      final raw = (await file.readAsString()).trim();
      for (final mode in ThemeMode.values) {
        if (mode.name == raw) {
          return mode;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(ThemeMode mode) async {
    try {
      final file = await _file();
      await file.writeAsString(mode.name);
    } catch (_) {}
  }
}
