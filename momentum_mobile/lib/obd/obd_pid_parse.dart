/// Decode Mode 01 responses from ELM327.
///
/// Accepts common variants:
/// - `41 0D 3A`
/// - `7E8 03 41 0D 3A`
/// - `410D3A`
List<int> _extractHexBytes(String line) {
  final matches = RegExp(r'[0-9A-Fa-f]{2}').allMatches(line);
  return [
    for (final m in matches) int.tryParse(m.group(0)!, radix: 16) ?? -1,
  ].where((b) => b >= 0).toList();
}

int? parseSpeedKph(String line) {
  final bytes = _extractHexBytes(line);
  if (bytes.length < 3) return null;
  for (var i = 0; i <= bytes.length - 3; i++) {
    if (bytes[i] == 0x41 && bytes[i + 1] == 0x0D) {
      return bytes[i + 2];
    }
  }
  return null;
}

double? parseRpm(String line) {
  final bytes = _extractHexBytes(line);
  if (bytes.length < 4) return null;
  for (var i = 0; i <= bytes.length - 4; i++) {
    if (bytes[i] == 0x41 && bytes[i + 1] == 0x0C) {
      final a = bytes[i + 2];
      final b = bytes[i + 3];
      return ((a * 256) + b) / 4.0;
    }
  }
  return null;
}

/// Engine load (PID 04): percentage (0–100) = A * 100 / 255.
double? parseEngineLoadPct(String line) {
  final bytes = _extractHexBytes(line);
  if (bytes.length < 3) return null;
  for (var i = 0; i <= bytes.length - 3; i++) {
    if (bytes[i] == 0x41 && bytes[i + 1] == 0x04) {
      final a = bytes[i + 2];
      return (a * 100.0) / 255.0;
    }
  }
  return null;
}

/// Engine coolant temperature (PID 05): degC = A - 40.
double? parseCoolantTempC(String line) {
  final bytes = _extractHexBytes(line);
  if (bytes.length < 3) return null;
  for (var i = 0; i <= bytes.length - 3; i++) {
    if (bytes[i] == 0x41 && bytes[i + 1] == 0x05) {
      final a = bytes[i + 2];
      return a - 40.0;
    }
  }
  return null;
}

/// Intake air temperature (PID 0F): degC = A - 40.
double? parseIntakeTempC(String line) {
  final bytes = _extractHexBytes(line);
  if (bytes.length < 3) return null;
  for (var i = 0; i <= bytes.length - 3; i++) {
    if (bytes[i] == 0x41 && bytes[i + 1] == 0x0F) {
      final a = bytes[i + 2];
      return a - 40.0;
    }
  }
  return null;
}

/// Throttle position (PID 11): percentage (0–100) = A * 100 / 255.
double? parseThrottlePct(String line) {
  final bytes = _extractHexBytes(line);
  if (bytes.length < 3) return null;
  for (var i = 0; i <= bytes.length - 3; i++) {
    if (bytes[i] == 0x41 && bytes[i + 1] == 0x11) {
      final a = bytes[i + 2];
      return (a * 100.0) / 255.0;
    }
  }
  return null;
}
