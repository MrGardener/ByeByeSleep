import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/challenge.dart';
import '../core/nfc.dart';

/// Touch the phone to the sticker registered at setup.
class NfcChallenge extends ConsumerStatefulWidget {
  const NfcChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<NfcChallenge> createState() => _NfcChallengeState();
}

class _NfcChallengeState extends ConsumerState<NfcChallenge> {
  late final NfcReader _reader = ref.read(nfcReaderProvider);
  StreamSubscription<String>? _sub;
  String? _message;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _reader.isAvailable().then((ok) {
      if (!ok && mounted) widget.args.onUnavailable?.call();
    }, onError: (Object _) => widget.args.onUnavailable?.call());
    _sub = _reader.tagIds().listen((id) {
      if (_done) return;
      if (id == widget.args.params['tagId']) {
        setState(() => _done = true);
        _reader.stop();
        widget.args.onPassed();
      } else {
        setState(() => _message = "That's a different sticker.");
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _reader.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_done ? Icons.check_circle : Icons.nfc, size: 72),
        const Text('Touch the back of the phone to your sticker.'),
        if (_message != null) Text(_message!),
      ],
    );
  }
}
