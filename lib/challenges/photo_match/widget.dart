import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/camera.dart';
import '../core/challenge.dart';

/// Retakes of the same view by hand score about 0.8–0.97 and other places
/// below 0.4 (see test/challenges/photo_similarity_test.dart).
const defaultPhotoThreshold = 0.6;

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

  // 'minMatch', not the old 'threshold': that was on the old scoring's
  // scale (0.9), which no handheld retake could reach.
  double get _threshold =>
      (widget.args.params['minMatch'] as num?)?.toDouble() ??
      defaultPhotoThreshold;

  Uint8List? _reference;

  @override
  void initState() {
    super.initState();
    _loadReference();
    _camera.init().then(
      (_) => mounted ? setState(() => _ready = true) : null,
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _error = 'Camera unavailable');
        widget.args.onUnavailable?.call();
      },
    );
  }

  Future<void> _loadReference() async {
    final photos = (widget.args.params['photos'] as List?) ?? const [];
    if (photos.isEmpty) return;
    final bytes = await ref
        .read(photoStoreProvider)
        .load(photos.first as String);
    if (mounted) setState(() => _reference = bytes);
  }

  void _showReference() => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: GestureDetector(
        key: const Key('photo-reference-large'),
        onTap: () => Navigator.of(context).pop(),
        child: Image.memory(
          _reference!,
          errorBuilder: (_, _, _) => const SizedBox(
            height: 200,
            child: Center(child: Icon(Icons.broken_image)),
          ),
        ),
      ),
    ),
  );

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
    final reference = _reference;
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: _error != null
                    ? Center(child: Text(_error!))
                    : _ready
                    ? _camera.preview()
                    : const Center(child: Text('Starting camera…')),
              ),
              // The view to find; tap to see it large.
              if (reference != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    key: const Key('photo-reference'),
                    onTap: _showReference,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Image.memory(
                        reference,
                        width: 96,
                        height: 128,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 96,
                          height: 128,
                          child: Icon(Icons.image),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Text('Match the photo in the corner (tap it to enlarge).'),
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
