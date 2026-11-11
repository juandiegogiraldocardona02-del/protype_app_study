import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

class ProfileAvatar extends ConsumerWidget {
  const ProfileAvatar({
    super.key,
    required this.profileId,
    required this.name,
    this.radius = 20,
  });

  final int profileId;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = ref.watch(profileAvatarProvider(profileId)).asData?.value;
    return CircleAvatar(
      radius: radius,
      backgroundImage: path == null ? null : FileImage(File(path)),
      onBackgroundImageError: path == null ? null : (_, _) {},
      child: path != null
          ? null
          : Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: TextStyle(fontSize: radius * 0.85),
            ),
    );
  }
}
