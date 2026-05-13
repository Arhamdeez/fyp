import '../live/obd_live_store.dart';
import '../telemetry/ride_record.dart';

double? _asDouble(dynamic x) {
  if (x == null) return null;
  if (x is num) return x.toDouble();
  return double.tryParse(x.toString());
}

int _clampScore(double v) => v.round().clamp(0, 100);

/// Alerts derived from telemetry, maintenance APIs, etc.
class VehicleAttention {
  VehicleAttention({
    required this.vehicleLabel,
    required this.title,
    required this.detail,
    this.severityHint,
    required this.isUrgent,
  });

  final String vehicleLabel;
  final String title;
  final String detail;
  final String? severityHint;
  final bool isUrgent;
}

/// One vehicle's derived health row.
class VehicleInsightResult {
  VehicleInsightResult({
    required this.vehicleId,
    required this.displayName,
    required this.healthScore,
    required this.healthLabel,
    required this.details,
    required this.telemetryAlerts,
  });

  final String vehicleId;
  final String displayName;
  final int healthScore;
  /// Short label: Good / Fair / Needs attention / Critical indicators
  final String healthLabel;
  /// Human bullets for dashboard (e.g. last sample cues).
  final List<String> details;
  final List<VehicleAttention> telemetryAlerts;
}

class FleetRollup {
  FleetRollup({
    required this.averageScore,
    required this.label,
    required this.summary,
    required this.sourcesCount,
    required this.worstInsight,
  });

  final int averageScore;
  final String label;
  final String summary;
  final int sourcesCount;
  /// Vehicle with lowest score, if any.
  final VehicleInsightResult? worstInsight;
}

String mapVerdictLine(RideVerdict v) => switch (v) {
      RideVerdict.good => 'Good — smooth recent drive',
      RideVerdict.moderate => 'Moderate — some sharp inputs',
      RideVerdict.harsh => 'Harsh — hard braking/accel or high RPM',
    };

List<String> _dtcList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
}

/// Latest server [VehicleData] row + vehicle display name.
VehicleInsightResult insightFromTelemetryRow({
  required String vehicleId,
  required String displayName,
  required Map<String, dynamic> row,
}) {
  var score = 100.0;
  final details = <String>[];
  final alerts = <VehicleAttention>[];

  final codes = _dtcList(row['error_codes']);
  if (codes.isNotEmpty) {
    score -= 38;
    final joined = codes.length > 4 ? '${codes.take(4).join(', ')}…' : codes.join(', ');
    alerts.add(
      VehicleAttention(
        vehicleLabel: displayName,
        title: 'Stored fault codes',
        detail: joined,
        isUrgent: true,
        severityHint: 'High',
      ),
    );
    details.add('DTCs present in last sample — scan and clear when repaired.');
  }

  final temp = _asDouble(row['engine_temp']);
  if (temp != null && temp > 1) {
    if (temp >= 110) {
      score -= 35;
      alerts.add(
        VehicleAttention(
          vehicleLabel: displayName,
          title: 'Engine temperature very high',
          detail: '${temp.toStringAsFixed(0)} °C — stop if climbing; check coolant.',
          isUrgent: true,
          severityHint: 'High',
        ),
      );
    } else if (temp >= 104) {
      score -= 18;
      alerts.add(
        VehicleAttention(
          vehicleLabel: displayName,
          title: 'Engine running hot',
          detail: '${temp.toStringAsFixed(0)} °C — monitor coolant and load.',
          isUrgent: false,
          severityHint: 'Medium',
        ),
      );
    } else {
      details.add('Engine temp ${temp.toStringAsFixed(0)} °C — in a normal band.');
    }
  }

  final fuel = _asDouble(row['fuel_level']);
  if (fuel != null) {
    if (fuel < 12) {
      score -= 12;
      alerts.add(
        VehicleAttention(
          vehicleLabel: displayName,
          title: 'Low fuel',
          detail: 'About ${fuel.toStringAsFixed(0)} % indicated — plan a fill-up.',
          isUrgent: false,
          severityHint: 'Medium',
        ),
      );
    } else if (fuel < 22) {
      details.add('Fuel near a quarter tank (${fuel.toStringAsFixed(0)} %).');
    }
  }

  final load = _asDouble(row['engine_load']);
  final rpm = _asDouble(row['rpm']);
  final speed = _asDouble(row['speed']);
  if (load != null && load >= 92 && rpm != null && rpm >= 5200 && (speed ?? 0) >= 55) {
    score -= 10;
    details.add('Last sample showed very high engine load near high RPM.');
  }

  if (details.isEmpty && alerts.isEmpty && temp != null && temp >= 85 && temp <= 98) {
    details.add('Last sample: telemetry looks stable.');
  }

  final clamped = _clampScore(score);
  final label = clamped >= 82
      ? 'Good'
      : (clamped >= 62 ? 'Fair' : (clamped >= 40 ? 'Needs attention' : 'Critical cues'));

  if (details.isEmpty && alerts.isEmpty) {
    details.add('No strong warning signals in the latest telemetry row.');
  }

  return VehicleInsightResult(
    vehicleId: vehicleId,
    displayName: displayName,
    healthScore: clamped,
    healthLabel: label,
    details: details,
    telemetryAlerts: alerts,
  );
}

VehicleInsightResult? insightFromObdLive({required String displayName}) {
  final o = ObdLiveStore.instance;
  if (!o.elmConnected) return null;
  final hasAnything = o.speedKph != null ||
      o.rpm != null ||
      o.engineLoadPct != null ||
      o.coolantTempC != null;
  if (!hasAnything) {
    return VehicleInsightResult(
      vehicleId: 'obd-live',
      displayName: displayName,
      healthScore: 92,
      healthLabel: 'Good',
      details: ['Adapter connected — waiting for PID data from the ECU.'],
      telemetryAlerts: [],
    );
  }

  var score = 100.0;
  final alerts = <VehicleAttention>[];
  final details = <String>[];

  final coolant = o.coolantTempC;
  if (coolant != null) {
    if (coolant >= 108) {
      score -= 32;
      alerts.add(
        VehicleAttention(
          vehicleLabel: displayName,
          title: 'Coolant very high (OBD)',
          detail: '${coolant.toStringAsFixed(0)} °C — check cooling system.',
          isUrgent: true,
          severityHint: 'High',
        ),
      );
    } else if (coolant >= 103) {
      score -= 16;
      alerts.add(
        VehicleAttention(
          vehicleLabel: displayName,
          title: 'Coolant elevated',
          detail: '${coolant.toStringAsFixed(0)} °C.',
          isUrgent: false,
          severityHint: 'Medium',
        ),
      );
    } else {
      details.add('Coolant ${coolant.toStringAsFixed(0)} °C.');
    }
  }

  final rpm = o.rpm;
  if (rpm != null) {
    if (rpm >= 5800 && (o.speedKph ?? 0) >= 40) {
      score -= 8;
      details.add('Engine speed peaked high — spirited driving stresses powertrain.');
    } else if (rpm >= 5200) {
      score -= 4;
      details.add('RPM is elevated vs typical cruise.');
    }
  }

  final loadPct = o.engineLoadPct;
  if (loadPct != null && loadPct >= 90) {
    score -= 5;
    details.add('Very high reported engine load.');
  }

  if (details.isEmpty) {
    details.add('Live gauges within a reasonable envelope.');
  }

  final spd = o.speedKph;
  final rpmRounded = rpm;
  details.insert(
    0,
    'Live: '
    '${spd != null ? '$spd km/h' : '—'}, '
    'RPM ${rpmRounded != null ? rpmRounded.toStringAsFixed(0) : '—'}.',
  );

  final clamped = _clampScore(score);
  final label = clamped >= 80
      ? 'Good'
      : (clamped >= 62 ? 'Fair' : 'Needs attention');

  return VehicleInsightResult(
    vehicleId: 'obd-live',
    displayName: displayName,
    healthScore: clamped,
    healthLabel: label,
    details: details,
    telemetryAlerts: alerts,
  );
}

FleetRollup rollupInsights(List<VehicleInsightResult> list) {
  if (list.isEmpty) {
    return FleetRollup(
      averageScore: 0,
      label: 'No data yet',
      summary: 'Add a saved vehicle with telemetry or connect your OBD adapter.',
      sourcesCount: 0,
      worstInsight: null,
    );
  }
  var sum = 0;
  for (final v in list) {
    sum += v.healthScore;
  }
  final avg = (sum / list.length).round().clamp(0, 100);
  var worst = list.first;
  for (var i = 1; i < list.length; i++) {
    final v = list[i];
    if (v.healthScore < worst.healthScore) worst = v;
  }

  final label = avg >= 82
      ? 'Healthy fleet snapshot'
      : (avg >= 65 ? 'Mostly okay' : (avg >= 45 ? 'Some risk signals' : 'Needs review'));

  final summary = '${list.length} source(s) • avg score ~$avg. '
      'Lowest: ${worst.displayName} (~${worst.healthScore}).';

  return FleetRollup(
    averageScore: avg,
    label: label,
    summary: summary,
    sourcesCount: list.length,
    worstInsight: worst,
  );
}

List<VehicleAttention> mapMaintenanceRecommendationRow({
  required String vehicleLabel,
  required Map<String, dynamic> raw,
}) {
  final sevStr = raw['severity']?.toString() ?? '';
  final urgent = sevStr == 'High';

  final title = raw['issue_type']?.toString().trim().isNotEmpty == true
      ? raw['issue_type'].toString()
      : raw['recommendation_type']?.toString().isNotEmpty == true
          ? raw['recommendation_type'].toString()
          : 'Maintenance note';

  final action = raw['suggested_action']?.toString() ?? '';
  final desc = raw['description']?.toString() ?? '';
  final detail = [desc, action].where((s) => s.trim().isNotEmpty).join(' — ');
  final body = detail.isEmpty ? '(No description)' : detail;

  return [
    VehicleAttention(
      vehicleLabel: vehicleLabel,
      title: title,
      detail: body,
      severityHint: sevStr.isEmpty ? null : sevStr,
      isUrgent: urgent,
    ),
  ];
}
