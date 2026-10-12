import 'dart:convert';

/// One recorded sensor reading. [tMicros] counts from the start of recording.
class TraceSample {
  const TraceSample(this.sensor, this.tMicros, this.x, this.y, this.z);

  factory TraceSample.fromJson(Map<String, Object?> j) => TraceSample(
    j['s']! as String,
    j['t']! as int,
    (j['x']! as num).toDouble(),
    (j['y']! as num).toDouble(),
    (j['z']! as num).toDouble(),
  );

  final String sensor;
  final int tMicros;
  final double x;
  final double y;
  final double z;

  Map<String, Object?> toJson() => {
    's': sensor,
    't': tMicros,
    'x': x,
    'y': y,
    'z': z,
  };
}

/// Recorded sensor streams, used as test fixtures (test/fixtures/traces/).
class SensorTrace {
  const SensorTrace(this.samples);

  factory SensorTrace.fromJson(String json) => SensorTrace([
    for (final s in jsonDecode(json) as List<Object?>)
      TraceSample.fromJson(s! as Map<String, Object?>),
  ]);

  final List<TraceSample> samples;

  String toJson() => jsonEncode([for (final s in samples) s.toJson()]);
}
