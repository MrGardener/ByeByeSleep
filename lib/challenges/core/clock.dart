import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic time for timing challenges; tests override it.
final challengeClockProvider = Provider<Duration Function()>((_) {
  final watch = Stopwatch()..start();
  return () => watch.elapsed;
});
