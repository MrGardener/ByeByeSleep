import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../challenges/core/motion.dart';
import 'trace.dart';

/// Developer tool: records accelerometer + gyroscope for a few seconds and
/// shares the JSON, to be committed under test/fixtures/traces/.
/// Opened by long-pressing the title on the alarm list.
class TraceRecorderScreen extends ConsumerStatefulWidget {
  const TraceRecorderScreen({super.key});

  @override
  ConsumerState<TraceRecorderScreen> createState() =>
      _TraceRecorderScreenState();
}

class _TraceRecorderScreenState extends ConsumerState<TraceRecorderScreen> {
  int _seconds = 10;
  bool _recording = false;
  int _count = 0;
  final _subs = <StreamSubscription<Object?>>[];

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _record() async {
    final motion = ref.read(motionSourceProvider);
    final samples = <TraceSample>[];
    final clock = Stopwatch()..start();
    setState(() {
      _recording = true;
      _count = 0;
    });
    void add(String sensor, double x, double y, double z) {
      samples.add(TraceSample(sensor, clock.elapsedMicroseconds, x, y, z));
      _count = samples.length;
    }

    _subs
      ..add(
        motion.accelerometer.listen((v) => add('accelerometer', v.x, v.y, v.z)),
      )
      ..add(motion.gyroscope.listen((v) => add('gyroscope', v.x, v.y, v.z)));
    await Future<void>.delayed(Duration(seconds: _seconds));
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    if (!mounted) return;
    setState(() => _recording = false);

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/trace-${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(SensorTrace(samples).toJson());
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'ByeByeSleep sensor trace'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor trace recorder')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Records the motion sensors and shares the JSON file. '
              'Do the movement you want to test while recording.',
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 5, label: Text('5 s')),
                ButtonSegment(value: 10, label: Text('10 s')),
                ButtonSegment(value: 30, label: Text('30 s')),
              ],
              selected: {_seconds},
              onSelectionChanged: _recording
                  ? null
                  : (s) => setState(() => _seconds = s.single),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('record-trace'),
              onPressed: _recording ? null : _record,
              icon: const Icon(Icons.fiber_manual_record),
              label: Text(_recording ? 'Recording… $_count samples' : 'Record'),
            ),
          ],
        ),
      ),
    );
  }
}
