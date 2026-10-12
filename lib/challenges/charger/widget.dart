import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/battery.dart';
import '../core/challenge.dart';
import 'detector.dart';

class ChargerChallenge extends ConsumerStatefulWidget {
  const ChargerChallenge({super.key, required this.args});

  final ChallengeArgs args;

  @override
  ConsumerState<ChargerChallenge> createState() => _ChargerChallengeState();
}

class _ChargerChallengeState extends ConsumerState<ChargerChallenge> {
  ChargerDetector? _d;
  StreamSubscription<bool>? _sub;
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final source = ref.read(chargeSourceProvider);
    final pluggedNow = await source.isPlugged();
    if (!mounted) return;
    setState(() => _d = ChargerDetector(pluggedAtStart: pluggedNow));
    _sub = source.plugged.listen((plugged) {
      final progress = _d!.onPlugged(plugged);
      setState(() {});
      if (progress.passed && !_reported) {
        _reported = true;
        widget.args.onPassed();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final text = d == null
        ? '…'
        : d.needsUnplug
        ? 'Unplug the phone, then plug it in at your other charger.'
        : 'Plug the phone into the charger away from your bed.';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.power, size: 72),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}
