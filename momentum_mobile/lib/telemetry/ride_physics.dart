/// Heuristics derived from successive speed samples (OBD PID 0D), same scale as ObdTab.
double? accelFromSpeedSamples({
  required int currentSpeedKph,
  required DateTime now,
  required int? previousSpeedKph,
  required DateTime? previousAt,
}) {
  if (previousSpeedKph == null || previousAt == null) return null;
  if (currentSpeedKph >= previousSpeedKph) return null;
  final dtSec = now.difference(previousAt).inMilliseconds / 1000.0;
  if (dtSec < 0.2) return null;
  final dvMs = (currentSpeedKph - previousSpeedKph) / 3.6;
  return dvMs / dtSec;
}

double? accelFromPositiveDelta({
  required int currentSpeedKph,
  required DateTime now,
  required int? previousSpeedKph,
  required DateTime? previousAt,
}) {
  if (previousSpeedKph == null || previousAt == null) return null;
  if (currentSpeedKph <= previousSpeedKph) return null;
  final dtSec = now.difference(previousAt).inMilliseconds / 1000.0;
  if (dtSec < 0.2) return null;
  final dvMs = (currentSpeedKph - previousSpeedKph) / 3.6;
  return dvMs / dtSec;
}
