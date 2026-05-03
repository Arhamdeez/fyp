/// Decode Mode 01 responses from ELM327.
///
/// Accepts common variants:
/// - `41 0D 3A`
/// - `7E8 03 41 0D 3A`
/// - `410D3A`
List<int> _extractHexBytes(String line) {
  final matches = RegExp(r'[0-9A-Fa-f]{2}').allMatches(line);
  return [
    for (final m in matches)
      int.tryParse(m.group(0)!, radix: 16) ?? -1,
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
