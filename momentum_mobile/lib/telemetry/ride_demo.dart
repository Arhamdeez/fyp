import 'ride_record.dart';

/// Deterministic rides for QA / previews (not from a real dongle).
class RideDemo {
  RideDemo._();

  /// Saves as the latest ride when inserted into [RideDb].
  static RideRecord smooth() {
    final ended = DateTime.now();
    final started = ended.subtract(const Duration(minutes: 9));
    const sampleCount = 280;
    const maxSpeedKph = 72;
    const maxRpm = 3200.0;
    const harshBrakingCount = 0;
    const harshAccelCount = 1;
    const highRpmSamples = 0;
    const avgLoad = 38.5;

    final verdict = RideRecord.computeVerdict(
      harshBrakingCount: harshBrakingCount,
      harshAccelCount: harshAccelCount,
      maxRpm: maxRpm,
      highRpmSamples: highRpmSamples,
    );

    final lines = RideRecord.buildSummaryLines(
      verdict: verdict,
      duration: ended.difference(started),
      sampleCount: sampleCount,
      maxSpeedKph: maxSpeedKph,
      maxRpm: maxRpm,
      harshBrakingCount: harshBrakingCount,
      harshAccelCount: harshAccelCount,
      highRpmSamples: highRpmSamples,
      avgEngineLoadPct: avgLoad,
    );

    return RideRecord(
      startedAt: started,
      endedAt: ended,
      adapterLabel: 'Demo · smooth city run',
      sampleCount: sampleCount,
      maxSpeedKph: maxSpeedKph,
      maxRpm: maxRpm,
      harshBrakingCount: harshBrakingCount,
      harshAccelCount: harshAccelCount,
      highRpmSamples: highRpmSamples,
      avgEngineLoadPct: avgLoad,
      verdict: verdict,
      summaryLines: lines,
    );
  }

  static RideRecord stressful() {
    final ended = DateTime.now();
    final started = ended.subtract(const Duration(minutes: 14));
    const sampleCount = 410;
    const maxSpeedKph = 112;
    const maxRpm = 6550.0;
    const harshBrakingCount = 9;
    const harshAccelCount = 8;
    const highRpmSamples = 58;
    const avgLoad = 68.0;

    final verdict = RideRecord.computeVerdict(
      harshBrakingCount: harshBrakingCount,
      harshAccelCount: harshAccelCount,
      maxRpm: maxRpm,
      highRpmSamples: highRpmSamples,
    );

    final lines = RideRecord.buildSummaryLines(
      verdict: verdict,
      duration: ended.difference(started),
      sampleCount: sampleCount,
      maxSpeedKph: maxSpeedKph,
      maxRpm: maxRpm,
      harshBrakingCount: harshBrakingCount,
      harshAccelCount: harshAccelCount,
      highRpmSamples: highRpmSamples,
      avgEngineLoadPct: avgLoad,
    );

    return RideRecord(
      startedAt: started,
      endedAt: ended,
      adapterLabel: 'Demo · spirited / harsh',
      sampleCount: sampleCount,
      maxSpeedKph: maxSpeedKph,
      maxRpm: maxRpm,
      harshBrakingCount: harshBrakingCount,
      harshAccelCount: harshAccelCount,
      highRpmSamples: highRpmSamples,
      avgEngineLoadPct: avgLoad,
      verdict: verdict,
      summaryLines: lines,
    );
  }
}
