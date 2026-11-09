import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/repository.dart';

class SubjectMusicPanel extends ConsumerStatefulWidget {
  const SubjectMusicPanel({super.key, required this.subject});

  final SubjectDto subject;

  @override
  ConsumerState<SubjectMusicPanel> createState() => _SubjectMusicPanelState();
}

class _SubjectMusicPanelState extends ConsumerState<SubjectMusicPanel> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  bool _busy = false;
  String? _audioPath;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _openSpotify() async {
    final uri = Uri.parse('https://open.spotify.com/');
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Spotify.')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openYouTube() async {
    final uri = Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent('estudio')}',
    );
    if (!await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir YouTube.')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickAudio() async {
    final files = await FilePicker.pickFiles(
      dialogTitle: 'Seleccionar audio para estudiar',
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
    );
    if (files.isEmpty) {
      return;
    }
    final path = files.first.path;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener la ruta local.')),
        );
      }
      return;
    }

    setState(() {
      _audioPath = path;
      _busy = true;
    });

    try {
      await _player.setAudioSource(AudioSource.uri(Uri.file(path)));
      await _player.play();
      if (mounted) {
        setState(() => _playing = true);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo reproducir el audio: $error')),
        );
      }
    }
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    await _player.play();
    if (mounted) setState(() => _playing = true);
  }

  Future<void> _stopPlayback() async {
    await _player.stop();
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Música', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Escuchar con Spotify',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Abre Spotify desde el navegador o la app mientras hay conexión.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _openSpotify(),
                  icon: const Icon(Icons.music_note),
                  label: const Text('Abrir Spotify'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YouTube para estudiar',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Abre YouTube con una búsqueda de estudio en el navegador.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _openYouTube(),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Abrir YouTube'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reproductor offline',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecciona un archivo de audio local para estudiar sin conexión.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _pickAudio(),
                  icon: const Icon(Icons.audiotrack_outlined),
                  label: const Text('Seleccionar audio local'),
                ),
                if (_audioPath != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _audioPath!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _togglePlayback,
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      ),
                      IconButton(
                        onPressed: _stopPlayback,
                        icon: const Icon(Icons.stop),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
