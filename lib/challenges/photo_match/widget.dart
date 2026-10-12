import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/camera.dart';
import '../core/challenge.dart';

const defaultPhotoThreshold = 0.9;

/// Take the same photo as the reference made at setup (spec §4.3).
class PhotoMatchChallenge extends ConsumerStatefulWidget {
  const PhotoMatchChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<PhotoMatchChallenge> createState() =>
      _PhotoMatchChallengeState();
}

class _PhotoMatchChallengeState extends ConsumerState<PhotoMatchChallenge> {
  late final PhotoCamera _camera = ref.read(photoCameraProvider)();
  bool _ready = false;
  bool _checking = false;
  double? _lastScore;
  String? _error;
  bool _reported = false;

  double get _threshold =>
      (widget.args.params['threshold'] as num?)?.toDouble() ??
      defaultPhotoThreshold;

  @override
  void initState() {
    super.initState();
    _camera.init().then(
      (_) => mounted ? setState(() => _ready = true) : null,
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _error = 'Camera unavailable');
        widget.args.onUnavailable?.call();
      },
    );
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final store = ref.read(photoStoreProvider);
    final score = ref.read(photoScorerProvider);
    final shot = await _camera.capture();
    var best = 0.0;
    for (final path in (widget.args.params['photos'] as List?) ?? const []) {
      final reference = await store.load(path as String);
      if (reference == null) continue;
      final s = await score(shot, reference);
      if (s > best) best = s;
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _lastScore = best;
    });
    if (best >= _threshold && !_reported) {
      _reported = true;
      widget.args.onPassed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = _lastScore;
    return Column(
      children: [
        Expanded(
          child: _error != null
              ? Center(child: Text(_error!))
              : _ready
              ? _camera.preview()
              : const Center(child: Text('Starting camera…')),
        ),
        if (score != null && score < _threshold)
          Text(
            'Not quite — ${(score * 100).round()}% match. '
            'Stand where you took the reference photo.',
            key: const Key('photo-score'),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('photo-check'),
          onPressed: _ready && !_checking ? _check : null,
          icon: const Icon(Icons.camera_alt),
          label: Text(_checking ? 'Checking…' : 'Check'),
        ),
      ],
    );
  }
}
