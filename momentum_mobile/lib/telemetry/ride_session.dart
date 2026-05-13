import 'ride_physics.dart';
import 'ride_record.dart';

/// Accumulates one connected OBD “ride” until [finish] is called.
class RideSession {
  RideSession({DateTime? startedAt}) : startedAt = startedAt ?? DateTime.now();

  final DateTime startedAt;

  int _samples = 0;
  int _maxSpeed = 0;
  double _maxRpm = 0;
  int _harshBrakes = 0;
  int _hardAccels = 0;
  int _highRpmSamples = 0;
  double _loadSum = 0;
  int _loadPoints = 0;

  DateTime _lastHardBrakeAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastHardAccelAt = DateTime.fromMillisecondsSinceEpoch(0);

  int? _lastSpeedForSpeed;
  DateTime? _lastSpeedAt;

  /// One snapshot per telemetry poll (~1 Hz). Skips ticks with no PID values yet.
  void ingestPollSnapshot({
    required DateTime now,
    int? speedKph,
    double? rpm,
    double? engineLoadPct,
  }) {
    if (speedKph == null && rpm == null && engineLoadPct == null) return;

    _samples++;

    if (speedKph != null) {
      final accelNeg = accelFromSpeedSamples(
        currentSpeedKph: speedKph,
        now: now,
        previousSpeedKph: _lastSpeedForSpeed,
        previousAt: _lastSpeedAt,
      );
      if (accelNeg != null && accelNeg <= -3.0) {
        if (now.difference(_lastHardBrakeAt) >= const Duration(seconds: 2)) {
          _harshBrakes++;
          _lastHardBrakeAt = now;
        }
      }

      final accelPos = accelFromPositiveDelta(
        currentSpeedKph: speedKph,
        now: now,
        previousSpeedKph: _lastSpeedForSpeed,
        previousAt: _lastSpeedAt,
      );
      if (accelPos != null && accelPos >= 3.0) {
        if (now.difference(_lastHardAccelAt) >= const Duration(seconds: 2)) {
          _hardAccels++;
          _lastHardAccelAt = now;
        }
      }

      _lastSpeedForSpeed = speedKph;
      _lastSpeedAt = now;
      if (speedKph > _maxSpeed) _maxSpeed = speedKph;
    }

    if (rpm != null) {
      if (rpm > _maxRpm) _maxRpm = rpm;
      if (rpm >= 4800) _highRpmSamples++;
    }

    if (engineLoadPct != null) {
      _loadSum += engineLoadPct;
      _loadPoints++;
    }
  }

  RideRecord finish({required DateTime endedAt, String? adapterLabel}) {
    final avgLoad = _loadPoints == 0 ? null : _loadSum / _loadPoints;

    final verdict = RideRecord.computeVerdict(
      harshBrakingCount: _harshBrakes,
      harshAccelCount: _hardAccels,
      maxRpm: _maxRpm,
      highRpmSamples: _highRpmSamples,
    );

    final lines = RideRecord.buildSummaryLines(
      verdict: verdict,
      duration: endedAt.difference(startedAt),
      sampleCount: _samples,
      maxSpeedKph: _maxSpeed,
      maxRpm: _maxRpm,
      harshBrakingCount: _harshBrakes,
      harshAccelCount: _hardAccels,
      highRpmSamples: _highRpmSamples,
      avgEngineLoadPct: avgLoad,
    );

    return RideRecord(
      startedAt: startedAt,
      endedAt: endedAt,
      adapterLabel: adapterLabel,
      sampleCount: _samples,
      maxSpeedKph: _maxSpeed,
      maxRpm: _maxRpm,
      harshBrakingCount: _harshBrakes,
      harshAccelCount: _hardAccels,
      highRpmSamples: _highRpmSamples,
      avgEngineLoadPct: avgLoad,
      verdict: verdict,
      summaryLines: lines,
    );
  }
}
