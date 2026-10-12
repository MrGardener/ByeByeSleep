import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/barcode_scanner.dart';
import '../core/challenge.dart';

/// Scan the barcode registered at setup (e.g. the toothpaste in the bathroom).
class BarcodeChallenge extends ConsumerStatefulWidget {
  const BarcodeChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<BarcodeChallenge> createState() => _BarcodeChallengeState();
}

class _BarcodeChallengeState extends ConsumerState<BarcodeChallenge> {
  String? _message;
  bool _done = false;

  void _onCode(String code) {
    if (_done) return;
    if (code == widget.args.params['code']) {
      setState(() => _done = true);
      widget.args.onPassed();
    } else {
      setState(() => _message = "That's a different barcode.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ref.read(barcodeScannerProvider)(
            _onCode,
            onError: widget.args.onUnavailable,
          ),
        ),
        const SizedBox(height: 8),
        const Text('Scan your registered barcode.'),
        if (_message != null) Text(_message!),
      ],
    );
  }
}
