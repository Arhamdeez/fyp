/// Decode simple Mode 01 responses from ELM327 (ASCII hex, e.g. `41 0D 3A`).
int? parseSpeedKph(String line) {
  final u = line.trim().toUpperCase();
  if (!u.startsWith('41 0D')) return null;
  final parts = u.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.length < 3) return null;
  return int.tryParse(parts[2], radix: 16);
}

double? parseRpm(String line) {
  final u = line.trim().toUpperCase();
  if (!u.startsWith('41 0C')) return null;
  final parts = u.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.length < 4) return null;
  final a = int.tryParse(parts[2], radix: 16);
  final b = int.tryParse(parts[3], radix: 16);
  if (a == null || b == null) return null;
  return ((a * 256) + b) / 4.0;
}
