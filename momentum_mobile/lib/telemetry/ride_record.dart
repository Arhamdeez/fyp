/// Verdict derived from aggregates collected during one OBD session.
enum RideVerdict {
  good,
  moderate,
  harsh,
}

class RideRecord {
  const RideRecord({
    this.id,
    required this.startedAt,
    required this.endedAt,
    this.adapterLabel,
    required this.sampleCount,
    required this.maxSpeedKph,
    required this.maxRpm,
    required this.harshBrakingCount,
    required this.harshAccelCount,
    required this.highRpmSamples,
    required this.avgEngineLoadPct,
    required this.verdict,
    required this.summaryLines,
  });

  factory RideRecord.fromRow(Map<String, Object?> row, List<String> summaryLines) {
    return RideRecord(
      id: row['id'] as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(row['started_at_ms'] as int),
      endedAt: DateTime.fromMillisecondsSinceEpoch(row['ended_at_ms'] as int),
      adapterLabel: row['adapter_label'] as String?,
      sampleCount: row['sample_count'] as int,
      maxSpeedKph: row['max_speed_kph'] as int,
      maxRpm: (row['max_rpm'] as num).toDouble(),
      harshBrakingCount: row['harsh_braking_count'] as int,
      harshAccelCount: row['harsh_accel_count'] as int,
      highRpmSamples: row['high_rpm_samples'] as int,
      avgEngineLoadPct: row['avg_engine_load_pct'] == null
          ? null
          : (row['avg_engine_load_pct'] as num).toDouble(),
      verdict: RideVerdict.values.firstWhere(
        (v) => v.name == row['verdict'],
        orElse: () => RideVerdict.moderate,
      ),
      summaryLines: summaryLines,
    );
  }

  final int? id;
  final DateTime startedAt;
  final DateTime endedAt;
  final String? adapterLabel;
  final int sampleCount;
  final int maxSpeedKph;
  final double maxRpm;
  final int harshBrakingCount;
  final int harshAccelCount;
  final int highRpmSamples;
  final double? avgEngineLoadPct;
  final RideVerdict verdict;

  /// Precomputed bullets for UI.
  final List<String> summaryLines;

  Duration get duration => endedAt.difference(startedAt);

  Map<String, Object?> toRowWithoutId() => {
        'started_at_ms': startedAt.millisecondsSinceEpoch,
        'ended_at_ms': endedAt.millisecondsSinceEpoch,
        'adapter_label': adapterLabel,
        'sample_count': sampleCount,
        'max_speed_kph': maxSpeedKph,
        'max_rpm': maxRpm,
        'harsh_braking_count': harshBrakingCount,
        'harsh_accel_count': harshAccelCount,
        'high_rpm_samples': highRpmSamples,
        'avg_engine_load_pct': avgEngineLoadPct,
        'verdict': verdict.name,
      };

  static RideVerdict computeVerdict({
    required int harshBrakingCount,
    required int harshAccelCount,
    required double maxRpm,
    required int highRpmSamples,
  }) {
    final hard = harshBrakingCount >= 5 ||
        harshAccelCount >= 5 ||
        maxRpm >= 6200 ||
        (harshBrakingCount + harshAccelCount >= 9);
    if (hard) return RideVerdict.harsh;

    final easy = harshBrakingCount <= 1 &&
        harshAccelCount <= 2 &&
        maxRpm < 4800 &&
        highRpmSamples <= 12;
    if (easy) return RideVerdict.good;

    return RideVerdict.moderate;
  }

  static List<String> buildSummaryLines({
    required RideVerdict verdict,
    required Duration duration,
    required int sampleCount,
    required int maxSpeedKph,
    required double maxRpm,
    required int harshBrakingCount,
    required int harshAccelCount,
    required int highRpmSamples,
    required double? avgEngineLoadPct,
  }) {
    final vLabel = switch (verdict) {
      RideVerdict.good => 'Overall this looks like a smooth, easy drive.',
      RideVerdict.moderate =>
        'Mixed style — a few sharper inputs; room to smooth throttle and braking.',
      RideVerdict.harsh =>
        'Harsh on the vehicle — frequent hard braking/acceleration or very high RPM.',
    };

    final m = duration.inMinutes;
    final s = duration.inSeconds.remainder(60);
    final dur = '${m}m ${s}s';

    return <String>[
      vLabel,
      'Recording window: $dur · $sampleCount telemetry samples.',
      'Peak speed ${maxSpeedKph > 0 ? '$maxSpeedKph km/h' : '(no speed readings)'}',
      if (maxRpm > 0)
        'Peak engine speed ${maxRpm.toStringAsFixed(0)} RPM.'
      else
        'Peak engine RPM not captured in samples.',
      'Harsh braking events (estimated from speed drops): $harshBrakingCount.',
      'Hard acceleration bursts: $harshAccelCount.',
      if (highRpmSamples > 0)
        'Samples with RPM at or above ~4800: $highRpmSamples.'
      else
        'No sampled moments at very high RPM (≥ ~4800).',
      if (avgEngineLoadPct != null)
        'Average engine load (where reported): ${avgEngineLoadPct.toStringAsFixed(1)} %.'
      else
        'Engine load was not aggregated for this ride.',
    ];
  }
}
