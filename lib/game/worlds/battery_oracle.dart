import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../challenges/core/battery.dart';

/// Guesses within 25 points of the real level pass (spec §7).
({int low, int high}) oracleRange(int actual) =>
    (low: (actual - 25).clamp(0, 100), high: (actual + 25).clamp(0, 100));

bool oracleAccepts(int guess, int actual) => (guess - actual).abs() <= 25;

/// Battery Oracle: guess the charge with the status bar hidden.
class BatteryOracleWorld extends ConsumerStatefulWidget {
  const BatteryOracleWorld({
    super.key,
    required this.onPassed,
    this.onUnavailable,
  });

  final VoidCallback onPassed;
  final VoidCallback? onUnavailable;

  @override
  ConsumerState<BatteryOracleWorld> createState() => _BatteryOracleState();
}

class _BatteryOracleState extends ConsumerState<BatteryOracleWorld> {
  final _input = TextEditingController();
  String? _error;
  ({int guess, int actual})? _result;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Hide the status bar, which shows the battery level.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final guess = int.tryParse(_input.text.trim());
    if (guess == null || guess < 0 || guess > 100) {
      setState(() => _error = 'Enter a number from 0 to 100');
      return;
    }
    setState(() {
      _error = null;
      _checking = true;
    });
    final int actual;
    try {
      actual = await ref.read(batteryLevelProvider).level();
    } catch (_) {
      if (!mounted) return;
      setState(() => _checking = false);
      widget.onUnavailable?.call();
      return;
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = (guess: guess, actual: actual);
    });
    if (oracleAccepts(guess, actual)) widget.onPassed();
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r != null) {
      final ok = oracleAccepts(r.guess, r.actual);
      final range = oracleRange(r.actual);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.auto_awesome : Icons.battery_unknown, size: 72),
          Text(
            ok ? 'The Oracle sees true!' : 'The mists deceived you.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('You guessed ${r.guess}%. The battery is at ${r.actual}%.'),
          Text('Accepted: ${range.low}–${range.high}%'),
          if (!ok)
            TextButton(
              onPressed: () => setState(() {
                _result = null;
                _input.clear();
              }),
              child: const Text('Try again'),
            ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.visibility_off, size: 72),
        const Text(
          'How full is the battery? Guess within 25%.',
          textAlign: TextAlign.center,
        ),
        SizedBox(
          width: 160,
          child: TextField(
            key: const Key('oracle-guess'),
            controller: _input,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(suffixText: '%', errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('oracle-submit'),
          onPressed: _checking ? null : _submit,
          child: const Text('Consult the Oracle'),
        ),
      ],
    );
  }
}
