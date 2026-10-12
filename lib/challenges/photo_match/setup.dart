import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/camera.dart';
import '../core/setup_scaffold.dart';
import 'widget.dart';

/// Two reference photos of the spot; their mutual score shows how stable the
/// scene is, and the threshold can be lowered for tricky rooms.
Future<Map<String, Object?>?> setupPhoto(
  BuildContext context,
  Map<String, Object?> current,
) => Navigator.of(context).push<Map<String, Object?>>(
  MaterialPageRoute(
    builder: (_) => _PhotoSetupScreen(
      threshold:
          (current['threshold'] as num?)?.toDouble() ?? defaultPhotoThreshold,
    ),
  ),
);

class _PhotoSetupScreen extends ConsumerStatefulWidget {
  const _PhotoSetupScreen({required this.threshold});

  final double threshold;

  @override
  ConsumerState<_PhotoSetupScreen> createState() => _PhotoSetupScreenState();
}

class _PhotoSetupScreenState extends ConsumerState<_PhotoSetupScreen> {
  late final PhotoCamera _camera = ref.read(photoCameraProvider)();
  late double _threshold = widget.threshold;
  final _shots = <Uint8List>[];
  final _paths = <String>[];
  double? _mutual;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _camera.init().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _take() async {
    final shot = await _camera.capture();
    final path = await ref.read(photoStoreProvider).save(shot);
    if (_shots.length == 2) {
      _shots.clear();
      _paths.clear();
      _mutual = null;
    }
    _shots.add(shot);
    _paths.add(path);
    if (_shots.length == 2) {
      _mutual = await ref.read(photoScorerProvider)(_shots[0], _shots[1]);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final mutual = _mutual;
    return SetupScaffold(
      title: 'Photo match — setup',
      explanation:
          'Go to your spot (kitchen, bathroom…) with the light on and take two '
          'photos of the same view, a few seconds apart.',
      onSave: _paths.length == 2
          ? () => {
              'photos': [..._paths],
              'threshold': _threshold,
            }
          : null,
      child: Column(
        children: [
          Expanded(
            child: _ready
                ? _camera.preview()
                : const Center(child: Text('Starting camera…')),
          ),
          Text('Photos taken: ${_shots.length} of 2'),
          if (mutual != null)
            Text('The two photos match ${(mutual * 100).round()}%'),
          if (mutual != null && mutual < _threshold + 0.03)
            Text(
              'These two photos differ a lot — pick a steadier view or lower '
              'the required match.',
              key: const Key('photo-warning'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Row(
            children: [
              Text('Required match ${(_threshold * 100).round()}%'),
              Expanded(
                child: Slider(
                  key: const Key('photo-threshold'),
                  value: _threshold,
                  min: 0.75,
                  max: 0.95,
                  divisions: 20,
                  onChanged: (v) => setState(() => _threshold = v),
                ),
              ),
            ],
          ),
          OutlinedButton.icon(
            key: const Key('photo-take'),
            onPressed: _ready ? _take : null,
            icon: const Icon(Icons.camera_alt),
            label: Text(_shots.length == 2 ? 'Retake both' : 'Take photo'),
          ),
        ],
      ),
    );
  }
}
