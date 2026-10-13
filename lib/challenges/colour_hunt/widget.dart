import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/camera.dart';
import '../core/challenge.dart';
import 'colour.dart';

/// Colour hunt: find something of the colour asked, fill the middle of the
/// camera view with it, tap Check.
class ColourHuntChallenge extends ConsumerStatefulWidget {
  const ColourHuntChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<ColourHuntChallenge> createState() => _ColourHuntState();
}

class _ColourHuntState extends ConsumerState<ColourHuntChallenge> {
  late final PhotoCamera _camera = ref.read(photoCameraProvider)();
  late final HuntColour _target =
      HuntColour.values.asNameMap()[widget.args.params['colour']] ??
      HuntColour.values[widget.args.random.nextInt(HuntColour.values.length)];
  bool _ready = false;
  bool _checking = false;
  String? _message;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _camera.init().then(
      (_) => mounted ? setState(() => _ready = true) : null,
      onError: (Object _) {
        if (mounted) widget.args.onUnavailable?.call();
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
    HuntColour? seen;
    try {
      seen = await compute(centreColour, await _camera.capture());
    } catch (_) {
      seen = null;
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _message = seen == null
          ? 'No clear colour in the middle — get closer.'
          : seen == _target
          ? 'Found it!'
          : 'That looks ${seen.label}. Find something ${_target.label}.';
    });
    if (seen == _target && !_done) {
      _done = true;
      widget.args.onPassed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Find something ${_target.label}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text('Fill the middle of the picture with it, then tap Check.'),
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: _ready
                    ? _camera.preview()
                    : const Center(child: Text('Starting camera…')),
              ),
              // The middle area that counts.
              IgnorePointer(
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 0.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_message != null) Text(_message!, textAlign: TextAlign.center),
        FilledButton.icon(
          key: const Key('colour-check'),
          onPressed: _ready && !_checking ? _check : null,
          icon: const Icon(Icons.camera_alt),
          label: Text(_checking ? 'Checking…' : 'Check'),
        ),
      ],
    );
  }
}
