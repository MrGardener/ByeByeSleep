import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import 'emergency.dart';

/// The emergency protocol: anyone (a partner, a roommate) can stop the alarm
/// by doing four things on the phone, in any order. Pops `true` to stop.
class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  final _protocol = EmergencyProtocol();
  StreamSubscription<void>? _keys;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    final source = ref.read(emergencySourceProvider);
    _keys = source.volumePresses.listen(
      (_) => setState(_protocol.volumePressed),
    );
    Future<void> check() async {
      final state = await source.radios();
      if (state != null && mounted) setState(() => _protocol.radios(state));
    }

    check();
    _poll = Timer.periodic(const Duration(milliseconds: 500), (_) => check());
  }

  @override
  void dispose() {
    _keys?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency stop')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'For anyone who cannot finish the challenges. Do these four '
            'things on this phone, in any order. Swipe down from the top '
            'of the screen for the Wi-Fi, Bluetooth and airplane switches.',
          ),
          const SizedBox(height: 16),
          for (final step in EmergencyStep.values)
            ListTile(
              key: Key(
                'step-${step.name}-'
                '${_protocol.done.contains(step) ? 'done' : 'todo'}',
              ),
              leading: Icon(
                _protocol.done.contains(step)
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: _protocol.done.contains(step)
                    ? SunriseColors.of(context).success
                    : null,
              ),
              title: Text(step.label),
            ),
          const SizedBox(height: 24),
          if (_protocol.complete)
            FilledButton(
              key: const Key('emergency-stop'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Emergency stop'),
              ),
            )
          else
            Text(
              '${_protocol.done.length} of ${EmergencyStep.values.length} done',
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 8),
          const Text(
            'Remember to turn Wi-Fi and Bluetooth back on and airplane mode '
            'off afterwards.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
